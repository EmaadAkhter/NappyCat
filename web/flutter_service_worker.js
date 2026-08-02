// Kill switch for the retired PWA cache. Clients that installed the old
// Flutter service worker check this URL for updates; this replacement
// activates, wipes every cache, unregisters itself, and reloads its pages —
// after which the app always loads fresh from hosting (see the no-cache
// headers in firebase.json). Delete this file if a real service worker
// ever returns (it would be overwritten by the generated one anyway).
self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((k) => caches.delete(k)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach((c) => c.navigate(c.url));
  })());
});
