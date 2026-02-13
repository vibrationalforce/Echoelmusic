/**
 * Echoelmusic Service Worker
 * Enables offline functionality and caching for PWA
 *
 * Future-proof for: WebXR (glasses), Web Bluetooth (wearables),
 * Background Sync, Push Notifications
 */

const CACHE_NAME = 'echoelmusic-v5.2.0';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/favicon.svg',
  '/app-icon.svg',
  '/manifest.json',
  '/version.json',
  '/fonts/atkinson-regular.woff2',
  '/fonts/atkinson-bold.woff2',
  '/fonts/atkinson-italic.woff2',
  '/privacy.html',
  '/terms.html',
  '/impressum.html',
  '/faq.html',
  '/support.html',
  '/health.html',
  '/security.html',
  '/accessibility.html'
];

const MAX_CACHE_ITEMS = 50;
async function trimCache(cacheName, maxItems) {
  const cache = await caches.open(cacheName);
  const keys = await cache.keys();
  if (keys.length > maxItems) {
    await Promise.all(keys.slice(0, keys.length - maxItems).map(k => cache.delete(k)));
  }
}

// Install: Cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Caching static assets');
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

// Activate: Clean old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => {
            console.log('[SW] Removing old cache:', key);
            return caches.delete(key);
          })
      );
    }).then(() => {
      trimCache(CACHE_NAME, MAX_CACHE_ITEMS);
      self.clients.matchAll().then(clients => {
        clients.forEach(client => client.postMessage({ type: 'SW_UPDATED', version: CACHE_NAME }));
      });
    })
  );
  self.clients.claim();
});

function fetchWithTimeout(request, timeout = 5000) {
  return Promise.race([
    fetch(request),
    new Promise((_, reject) => setTimeout(() => reject(new Error('Network timeout')), timeout))
  ]);
}

// Fetch: Network-first with cache fallback
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') return;

  // Skip cross-origin requests
  if (!event.request.url.startsWith(self.location.origin)) return;

  // Cache-first for immutable assets (fonts, images)
  const url = new URL(event.request.url);
  if (url.pathname.startsWith('/fonts/') || url.pathname.endsWith('.svg') || url.pathname.endsWith('.png')) {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        if (cached) return cached;
        return fetch(event.request).then((response) => {
          if (response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return response;
        });
      })
    );
    return;
  }

  event.respondWith(
    fetchWithTimeout(event.request)
      .then((response) => {
        // Cache successful responses
        if (response.status === 200) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }
        return response;
      })
      .catch(() => {
        // Fallback to cache when offline
        return caches.match(event.request).then((response) => {
          if (response) {
            return response;
          }
          // Fallback to main page for navigation requests
          if (event.request.mode === 'navigate') {
            return caches.match('/');
          }
        });
      })
  );
});

// Background Sync (future: sync bio data when back online)
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-biodata') {
    console.log('[SW] Background sync: biodata');
    // Future: Sync accumulated biometric data
  }
});

// Push Notifications (future: coherence reminders)
self.addEventListener('push', (event) => {
  if (event.data) {
    const data = event.data.json();
    event.waitUntil(
      self.registration.showNotification(data.title || 'Echoelmusic', {
        body: data.body || 'Time for your coherence session',
        icon: '/favicon.svg',
        badge: '/favicon.svg',
        vibrate: [100, 50, 100],
        tag: 'echoelmusic-notification',
        data: data
      })
    );
  }
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((clientList) => {
      // Focus existing window or open new
      for (const client of clientList) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});

// Message handler for future WebXR/Bluetooth coordination
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  // Future: Handle WebXR session state
  if (event.data && event.data.type === 'XR_SESSION_START') {
    console.log('[SW] WebXR session started');
  }

  // Future: Handle Web Bluetooth device connection
  if (event.data && event.data.type === 'BLUETOOTH_CONNECTED') {
    console.log('[SW] Bluetooth device connected:', event.data.device);
  }
});

console.log('[SW] Echoelmusic Service Worker loaded');
