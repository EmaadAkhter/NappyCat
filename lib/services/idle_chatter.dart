import 'dart:math';

/// The 40 canned lines from CatMessageLibrary.swift, preserved verbatim.
///
/// These are no longer what the cat *says* — a real letter always wins. They are
/// what it murmurs when the mailbox is empty, so the app never feels dead
/// between letters. Flutter picks the line and hands it to the native widgets in
/// the shared payload, so this list lives only here (not duplicated in Swift and
/// Kotlin).
class IdleChatter {
  const IdleChatter._();

  static const lines = <String>[
    "Zzz... 5 more minutes of naps, human! 🐾",
    "Huh? Was that the sound of a treat bag opening?! 🍗",
    "I was having a dream about a giant cheese wheel 🧀",
    "Yawwwwn... You disturbed my 14th nap of the day!",
    "Pat my head and maybe I'll let you hold my paw 🐾",
    "Feed me chicken and no one gets hurt! 😼",
    "I'm not lazy, I'm conserving my cat energy.",
    "Mew! Is it snack time yet? Please say yes! 🥣",
    "Did somebody say tuna?! I am wide awake! 🐟",
    "I'm purr-fectly content right here on this soft pillow.",
    "Don't worry, I was just resting my eyes for a sec.",
    "My hood keeps my ears extra warm and extra cute! 👒",
    "If I fit, I sit. If I nap, I nap! 📦",
    "Shh... I'm listening to the birds outside 🐦",
    "Give me belly rubs (but only 3 seconds max)!",
    "I love you more than laser pointers! ❤️",
    "Good day! Please hand over the catnip immediately.",
    "I'm warm, cuddly, and 99% fluff! ✨",
    "Who summoned the supreme nap master?! 👑",
    "Just checking to make sure you're working hard to buy my treats!",
    "My cozy hood is my armor against morning alarm clocks.",
    "Snoozing is my full-time job, and I take it very seriously 😴",
    "Meow! You woke me up just in time for cuddles!",
    "Is there a sunny spot nearby? Lead the way!",
    "I smell snacks in the kitchen... don't hide them!",
    "Purrrr... Your tap warmed my tiny heart! 💕",
    "Wake me up when it's dinner time! 🍲",
    "I'm not sleeping, I'm just meditating on salmon 🍣",
    "Scratch behind my ears and I'll grant you 3 wishes!",
    "I'm officially on do-not-disturb mode 🚫💤",
    "Big stretch! Okay, back to sleep I go...",
    "Did you bring me a cardboard box to play in?",
    "My nap schedule is very strict, human!",
    "Soft kitty, warm kitty, little ball of fluff 🎶",
    "I'm the king of the home screen! 👑🐾",
    "Keep calm and pet the cat!",
    "Sending you a warm virtual purr! 🐱✨",
    "Ah! Bright light! Let me wear my sleep mask!",
    "You tapped! That means treat time, right?",
    "Nap count: 18 today. Target: 24 naps!",
  ];

  static final _rng = Random();

  /// Avoids repeating [previous] so two consecutive taps never show the same
  /// line — the Swift original had no such guard and it read as a bug.
  static String random({String? previous}) {
    if (lines.length < 2) return lines.first;
    String pick;
    do {
      pick = lines[_rng.nextInt(lines.length)];
    } while (pick == previous);
    return pick;
  }
}
