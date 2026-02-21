/*
 *  service-worker.js
 *  Echoelmusic — PWA Service Worker
 *
 *  Created: February 2026
 *  Enables offline-first hybrid app with:
 *  - WebAssembly DSP engine caching
 *  - Audio worklet caching
 *  - Asset precaching
 *  - Background sync for cloud sessions
 *  - Push notifications for collaboration
 */

const CACHE_NAME = 'echoelmusic-v2.0.0';
const WASM_CACHE = 'echoelmusic-wasm-v2.0.0';

/* Assets to precache for offline use */
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/css/echoel.css',
  '/js/echoel-app.js',
  '/js/echoel-audio-worklet.js',
  '/wasm/echoelmusic.wasm',
  '/wasm/echoelmusic.js',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
];

/* WebAssembly + Audio files (larger, separate cache) */
const WASM_ASSETS = [
  '/wasm/echoelmusic.wasm',
  '/wasm/echoelmusic-simd.wasm',
  '/audio/impulse-responses/hall.wav',
  '/audio/impulse-responses/plate.wav',
];

/* ─── Install ─── */

self.addEventListener('install', (event) => {
  event.waitUntil(
    Promise.all([
      caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_ASSETS)),
      caches.open(WASM_CACHE).then((cache) => cache.addAll(WASM_ASSETS)),
    ]).then(() => self.skipWaiting())
  );
});

/* ─── Activate ─── */

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME && key !== WASM_CACHE)
          .map((key) => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

/* ─── Fetch ─── */

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  /* WebAssembly: cache-first (large, rarely changes) */
  if (url.pathname.endsWith('.wasm')) {
    event.respondWith(
      caches.match(event.request).then((cached) =>
        cached || fetch(event.request).then((response) => {
          const clone = response.clone();
          caches.open(WASM_CACHE).then((cache) => cache.put(event.request, clone));
          return response;
        })
      )
    );
    return;
  }

  /* Audio files: cache-first */
  if (url.pathname.startsWith('/audio/')) {
    event.respondWith(
      caches.match(event.request).then((cached) =>
        cached || fetch(event.request).then((response) => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return response;
        })
      )
    );
    return;
  }

  /* API calls: network-first */
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(event.request))
    );
    return;
  }

  /* Everything else: stale-while-revalidate */
  event.respondWith(
    caches.match(event.request).then((cached) => {
      const fetchPromise = fetch(event.request).then((response) => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => cached);

      return cached || fetchPromise;
    })
  );
});

/* ─── Background Sync (save session when back online) ─── */

self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-session') {
    event.waitUntil(syncSession());
  }
});

async function syncSession() {
  /* Retrieve pending session data from IndexedDB and POST to server */
  /* Implementation depends on backend API */
}

/* ─── Push Notifications (collaboration, render complete) ─── */

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};

  const options = {
    body: data.body || 'New update in Echoelmusic',
    icon: '/icons/icon-192.png',
    badge: '/icons/badge-72.png',
    vibrate: [100, 50, 100],
    data: { url: data.url || '/' },
    actions: [
      { action: 'open', title: 'Open' },
      { action: 'dismiss', title: 'Dismiss' },
    ],
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'Echoelmusic', options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  if (event.action === 'open' || !event.action) {
    event.waitUntil(
      clients.openWindow(event.notification.data.url)
    );
  }
});
