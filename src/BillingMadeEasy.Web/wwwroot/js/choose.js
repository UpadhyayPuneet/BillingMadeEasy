// Business picker: press 1–9 to choose, arrows to move.
(function () {
    'use strict';
    var form = document.querySelector('[data-number-keys]');
    if (!form) return;
    var choices = Array.prototype.slice.call(form.querySelectorAll('.choice'));
    if (choices.length) (form.querySelector('.choice[aria-current="true"]') || choices[0]).focus();

    document.addEventListener('keydown', function (e) {
        if (e.ctrlKey || e.metaKey || e.altKey) return;
        var hit = form.querySelector('.choice[data-key="' + e.key + '"]');
        if (hit) { e.preventDefault(); hit.click(); return; }
        var i = choices.indexOf(document.activeElement);
        if (e.key === 'ArrowDown' && i < choices.length - 1) { e.preventDefault(); choices[i + 1].focus(); }
        if (e.key === 'ArrowUp' && i > 0) { e.preventDefault(); choices[i - 1].focus(); }
    });
})();
