// The site used to run the web version, which installed this service worker.
// The site now runs the Godot build (it has its own worker), so this one clears
// the old offline cache, removes itself and reloads any open tabs.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('pokepop-v')).map((k) => caches.delete(k))))
      .then(() => self.registration.unregister())
      .then(() => self.clients.matchAll({ type: 'window' }))
      .then((tabs) => tabs.forEach((t) => t.navigate(t.url)))
  );
});
