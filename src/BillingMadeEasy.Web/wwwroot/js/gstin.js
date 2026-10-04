(function () {
    'use strict';
    var input = document.getElementById('gstin');
    var out = document.getElementById('gstin-result');
    if (!input || !out) return;

    var reasons = {
        WrongLength: 'A GSTIN has 15 characters.',
        WrongFormat: "The pattern isn't right: 2 digits, PAN, entity number, Z, check character.",
        UnknownState: "The first two digits aren't a GST state code.",
        ChecksumMismatch: "The last character doesn't match. Usually one character was typed wrong."
    };
    var timer = null, seq = 0;

    function show(cls, html) { out.className = 'result ' + cls; out.innerHTML = html; }
    function esc(s) { var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

    input.addEventListener('input', function () {
        var value = input.value.replace(/\s+/g, '').toUpperCase();
        if (input.value !== value) input.value = value;
        clearTimeout(timer);
        if (!value) { show('', ''); return; }
        if (value.length < 15) { show('', esc(15 - value.length + ' more to go')); return; }

        var mine = ++seq;
        timer = setTimeout(function () {
            fetch('/api/core/gstin/' + encodeURIComponent(value), { headers: { Accept: 'application/json' } })
                .then(function (r) { return r.json(); })
                .then(function (d) {
                    if (mine !== seq) return;
                    if (d.valid) {
                        show('ok', '<span class="ms" aria-hidden="true">check_circle</span> Valid · ' + esc(d.state) +
                            ' (' + esc(d.stateCode) + ') · PAN ' + esc(d.pan));
                    } else {
                        show('bad', '<span class="ms" aria-hidden="true">error</span> ' + esc(reasons[d.reason] || 'Not a valid GSTIN.'));
                    }
                })
                .catch(function () { if (mine === seq) show('bad', "Couldn't check right now."); });
        }, 150);
    });
})();
