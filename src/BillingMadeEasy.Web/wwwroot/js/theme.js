// Runs in <head>, before first paint, so there is never a flash of the wrong theme.
(function () {
    var stored = null;
    try { stored = localStorage.getItem('bme.theme'); } catch (e) { /* private mode */ }
    if (stored === 'light' || stored === 'dark') document.documentElement.setAttribute('data-theme', stored);
})();
