{{flutter_js}}
{{flutter_build_config}}

// Local review builds should always load the current character definitions.
// Retire workers from earlier preview builds before initializing Flutter.
(async () => {
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const registration of registrations) await registration.unregister();
    if (registrations.length) {
      for (const key of await caches.keys()) await caches.delete(key);
      location.reload();
      return;
    }
  }
  _flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
})();
