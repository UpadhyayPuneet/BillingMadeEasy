// The invoice document: accent colour, which copy is being printed, and printing.
(function () {
    'use strict';
    var doc = document.querySelector('.invoice-doc');
    if (!doc) return;
    var accent = doc.getAttribute('data-accent');
    if (/^#[0-9A-Fa-f]{6}$/.test(accent || '')) doc.style.setProperty('--doc-accent', accent);

    var pick = document.querySelector('[data-copy-label]'), label = document.querySelector('[data-copy-text]');
    if (pick && label) pick.addEventListener('change', function () { label.textContent = pick.value; });

    document.querySelectorAll('[data-print]').forEach(function (b) { b.addEventListener('click', function () { window.print(); }); });
})();
