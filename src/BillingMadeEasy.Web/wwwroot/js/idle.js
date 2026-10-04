// Locks the screen after the business's idle limit without waiting for the next click.
// Activity in any tab of the app counts, so a second open tab never locks out the one in use.
// The server applies the same rule independently; this only makes the lock visible on time.
(function () {
    'use strict';
    var el = document.getElementById('bme-idle');
    var minutes = el ? parseInt(el.textContent, 10) : 0;
    if (!minutes || minutes < 1) return;

    var KEY = 'bme.activity';
    // A little past the limit so the server, which counts whole minutes, agrees it is idle.
    var limitMs = minutes * 60000 + 30000;
    var last = Date.now();

    function read() {
        try { return Math.max(last, parseInt(localStorage.getItem(KEY) || '0', 10) || 0); } catch (e) { return last; }
    }
    function touch() {
        var now = Date.now();
        if (now - last < 5000) return;           // at most one write every 5 s
        last = now;
        try { localStorage.setItem(KEY, String(now)); } catch (e) { /* private mode */ }
    }
    ['keydown', 'mousedown', 'mousemove', 'wheel', 'touchstart', 'scroll'].forEach(function (type) {
        window.addEventListener(type, touch, { passive: true, capture: true });
    });
    touch();

    function check() {
        if (Date.now() - read() < limitMs) return;
        var here = location.pathname + location.search;
        location.replace('/Account/Unlock?ReturnUrl=' + encodeURIComponent(here));
    }
    setInterval(check, 15000);
    document.addEventListener('visibilitychange', function () { if (!document.hidden) check(); });
})();
