import { readFileSync } from 'node:fs';
import assert from 'node:assert';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, updateDoc, deleteDoc, getDoc, getDocs, collection,
  writeBatch, serverTimestamp, Timestamp,
} from 'firebase/firestore';

const PAIR = 'TIDECODE1';
const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;

let env, alice, bob, carol;

const msgs = (db) => collection(db, 'pairs', PAIR, 'messages');
const msgRef = (db, id) => doc(db, 'pairs', PAIR, 'messages', id);

// A well-formed message from alice to bob. Individual tests override fields.
const letter = (over = {}) => ({
  senderId: 'alice',
  recipientId: 'bob',
  text: 'the tide came in today',
  sentAt: serverTimestamp(),
  openedAt: null,
  expiresAt: Timestamp.fromMillis(Date.now() + 90 * DAY),
  senderCatId: 'koala',
  senderName: 'Alice',
  ...over,
});

// The ONLY legal send shape: message create + lastSentAt stamp in one batch.
function send(db, uid, id, over = {}) {
  const batch = writeBatch(db);
  batch.set(msgRef(db, id), letter(over));
  batch.update(doc(db, 'users', uid), { lastSentAt: serverTimestamp() });
  return batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-tidal',
    firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8089 },
  });
  alice = env.authenticatedContext('alice').firestore();
  bob = env.authenticatedContext('bob').firestore();
  carol = env.authenticatedContext('carol').firestore();
});

after(() => env.cleanup());

// Fresh state per test: alice and bob paired, neither has ever sent.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'alice'), { displayName: 'Alice', catId: 'koala', createdAt: Timestamp.now() });
    await setDoc(doc(db, 'users', 'bob'), { displayName: 'Bob', catId: 'tabby', createdAt: Timestamp.now() });
    await setDoc(doc(db, 'pairs', PAIR), {
      memberIds: ['alice', 'bob'],
      createdAt: Timestamp.now(),
      inviteExpiresAt: Timestamp.fromMillis(Date.now() + 12 * HOUR),
    });
  });
});

// Backdate alice's last send so the cooldown has elapsed.
const aliceSentHoursAgo = (h) => env.withSecurityRulesDisabled((ctx) =>
  updateDoc(doc(ctx.firestore(), 'users', 'alice'), {
    lastSentAt: Timestamp.fromMillis(Date.now() - h * HOUR),
  }));

// Put an unopened letter in bob's inbox without going through the rules.
const seedLetter = (id, over = {}) => env.withSecurityRulesDisabled((ctx) =>
  setDoc(msgRef(ctx.firestore(), id), {
    ...letter(over), sentAt: Timestamp.now(),
  }));

describe('rate limit — the load-bearing rule', () => {
  it('allows a first send when batched correctly', async () => {
    await assertSucceeds(send(alice, 'alice', 'm1'));
  });

  it('DENIES a send that skips the lastSentAt stamp (the getAfter hole)', async () => {
    // This is the bypass the whole design exists to close: write the message
    // alone and never stamp the user doc.
    await assertFails(setDoc(msgRef(alice, 'm1'), letter()));
  });

  it('DENIES a second send inside the cooldown', async () => {
    await assertSucceeds(send(alice, 'alice', 'm1'));
    await assertFails(send(alice, 'alice', 'm2'));
  });

  it('allows the next send once the cooldown has elapsed', async () => {
    await aliceSentHoursAgo(9);
    await assertSucceeds(send(alice, 'alice', 'm2'));
  });

  it('DENIES a forged client timestamp instead of serverTimestamp()', async () => {
    const batch = writeBatch(alice);
    batch.set(msgRef(alice, 'm1'), letter());
    batch.update(doc(alice, 'users', 'alice'), {
      lastSentAt: Timestamp.fromMillis(Date.now() - 9 * HOUR),
    });
    await assertFails(batch.commit());
  });

  it('DENIES stamping lastSentAt without sending anything', async () => {
    await assertSucceeds(send(alice, 'alice', 'm1'));
    await assertFails(updateDoc(doc(alice, 'users', 'alice'), { lastSentAt: serverTimestamp() }));
  });

  it('DENIES smuggling lastSentAt through a profile update', async () => {
    await assertFails(updateDoc(doc(alice, 'users', 'alice'), {
      displayName: 'Alice2', lastSentAt: Timestamp.fromMillis(0),
    }));
  });
});

describe('message create validation', () => {
  it('DENIES sending as someone else', async () => {
    await assertFails(send(alice, 'alice', 'm1', { senderId: 'bob', recipientId: 'alice' }));
  });

  it('DENIES sending to yourself', async () => {
    await assertFails(send(alice, 'alice', 'm1', { recipientId: 'alice' }));
  });

  it('DENIES empty and over-long text', async () => {
    await assertFails(send(alice, 'alice', 'm1', { text: '' }));
    await env.clearFirestore();
    await beforeEachSeed();
    await assertFails(send(alice, 'alice', 'm2', { text: 'x'.repeat(281) }));
  });

  it('DENIES omitting openedAt (must be present-and-null for the inbox query)', async () => {
    const over = letter();
    delete over.openedAt;
    const batch = writeBatch(alice);
    batch.set(msgRef(alice, 'm1'), over);
    batch.update(doc(alice, 'users', 'alice'), { lastSentAt: serverTimestamp() });
    await assertFails(batch.commit());
  });

  it('DENIES an expiresAt outside the 90-day sentinel window', async () => {
    await assertFails(send(alice, 'alice', 'm1', {
      expiresAt: Timestamp.fromMillis(Date.now() + 5 * DAY),
    }));
  });

  it('DENIES a non-member sending into the pair', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'users', 'carol'),
        { displayName: 'Carol', catId: 'ginger', createdAt: Timestamp.now() }));
    await assertFails(send(carol, 'carol', 'm1', { senderId: 'carol', recipientId: 'bob' }));
  });
});

describe('opening a letter', () => {
  const openPayload = (ms = Date.now()) => ({
    openedAt: Timestamp.fromMillis(ms),
    expiresAt: Timestamp.fromMillis(ms + 16 * HOUR),
  });

  it('allows the recipient to open it once', async () => {
    await seedLetter('m1');
    await assertSucceeds(updateDoc(msgRef(bob, 'm1'), openPayload()));
  });

  it('DENIES the sender opening their own letter', async () => {
    await seedLetter('m1');
    await assertFails(updateDoc(msgRef(alice, 'm1'), openPayload()));
  });

  it('DENIES re-opening (the 16h clock cannot be restarted)', async () => {
    await seedLetter('m1');
    await assertSucceeds(updateDoc(msgRef(bob, 'm1'), openPayload()));
    await assertFails(updateDoc(msgRef(bob, 'm1'), openPayload()));
  });

  it('DENIES an expiresAt that does not equal openedAt + 16h', async () => {
    await seedLetter('m1');
    const ms = Date.now();
    await assertFails(updateDoc(msgRef(bob, 'm1'), {
      openedAt: Timestamp.fromMillis(ms),
      expiresAt: Timestamp.fromMillis(ms + 40 * DAY),   // trying to keep it forever
    }));
  });

  it('DENIES opening with a far-future clock', async () => {
    await seedLetter('m1');
    await assertFails(updateDoc(msgRef(bob, 'm1'), openPayload(Date.now() + 2 * DAY)));
  });

  it('DENIES editing the text while opening', async () => {
    await seedLetter('m1');
    await assertFails(updateDoc(msgRef(bob, 'm1'), { ...openPayload(), text: 'rewritten' }));
  });

  it('DENIES deleting a message', async () => {
    await seedLetter('m1');
    await assertFails(deleteDoc(msgRef(bob, 'm1')));
    await assertFails(deleteDoc(msgRef(alice, 'm1')));
  });
});

describe('pair access', () => {
  it('lets members read the thread and blocks outsiders', async () => {
    await seedLetter('m1');
    await assertSucceeds(getDocs(msgs(bob)));
    await assertFails(getDocs(msgs(carol)));
  });

  it('DENIES a third person joining a full pair', async () => {
    await assertFails(updateDoc(doc(carol, 'pairs', PAIR), {
      memberIds: ['alice', 'bob', 'carol'],
    }));
  });

  it('lets a second person join an open invite, then blocks a third', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'pairs', 'OPENCODE1'), {
        memberIds: ['alice'],
        createdAt: Timestamp.now(),
        inviteExpiresAt: Timestamp.fromMillis(Date.now() + 12 * HOUR),
      }));
    await assertSucceeds(updateDoc(doc(bob, 'pairs', 'OPENCODE1'), { memberIds: ['alice', 'bob'] }));
    await assertFails(updateDoc(doc(carol, 'pairs', 'OPENCODE1'), { memberIds: ['alice', 'bob', 'carol'] }));
  });

  it('DENIES an expired invite', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'pairs', 'STALECODE'), {
        memberIds: ['alice'],
        createdAt: Timestamp.fromMillis(Date.now() - 2 * DAY),
        inviteExpiresAt: Timestamp.fromMillis(Date.now() - DAY),
      }));
    await assertFails(updateDoc(doc(bob, 'pairs', 'STALECODE'), { memberIds: ['alice', 'bob'] }));
  });

  it('DENIES enumerating pairs (invite codes must not be discoverable)', async () => {
    await assertFails(getDocs(collection(carol, 'pairs')));
  });

  it('DENIES reading another user profile', async () => {
    await assertFails(getDoc(doc(carol, 'users', 'alice')));
  });
});

// Used by the one test that needs to re-seed mid-body.
async function beforeEachSeed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'alice'), { displayName: 'Alice', catId: 'koala', createdAt: Timestamp.now() });
    await setDoc(doc(db, 'users', 'bob'), { displayName: 'Bob', catId: 'tabby', createdAt: Timestamp.now() });
    await setDoc(doc(db, 'pairs', PAIR), {
      memberIds: ['alice', 'bob'],
      createdAt: Timestamp.now(),
      inviteExpiresAt: Timestamp.fromMillis(Date.now() + 12 * HOUR),
    });
  });
}
