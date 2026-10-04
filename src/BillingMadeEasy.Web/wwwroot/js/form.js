// Shared form behaviour for every create/edit screen:
//   Ctrl+Enter / Ctrl+S save · Esc cancels (asks first if anything changed)
//   amount shorthand: 25k → 25000, 1.5L → 150000, 2cr → 20000000, =1200*3 → 3600
//   GSTIN assist: live check, PAN and state filled from it
//   data-reveal: a checkbox shows/hides the section it controls
(function () {
    'use strict';
    var form = document.querySelector('form[data-form]');
    var dirty = false, submitting = false;

    if (form) wireForm();

    function wireForm() {
        form.addEventListener('input', function () { dirty = true; });
        form.addEventListener('change', function () { dirty = true; });
        form.addEventListener('submit', function () {
            submitting = true;
            var button = form.querySelector('button[type="submit"]');
            if (button) { button.disabled = true; button.setAttribute('aria-busy', 'true'); }
        });
        window.addEventListener('beforeunload', function (e) {
            if (dirty && !submitting) { e.preventDefault(); e.returnValue = ''; }
        });

        document.addEventListener('keydown', function (e) {
            var ctrl = e.ctrlKey || e.metaKey;
            if (ctrl && (e.key === 'Enter' || e.key === 's' || e.key === 'S')) {
                e.preventDefault();
                if (!submitting) form.requestSubmit();
                return;
            }
            if (e.key === 'Escape' && !document.querySelector('[data-palette]:not([hidden]), dialog[open]')) {
                var cancel = form.querySelector('[data-cancel]');
                if (!cancel) return;
                if (dirty && !confirm('Discard your changes?')) return;
                dirty = false;
                location.href = cancel.getAttribute('href');
            }
        });
    }

    // ── Upper-case fields (PAN, GSTIN) as you type, without jumping the caret ──
    document.querySelectorAll('input.upper').forEach(function (input) {
        input.addEventListener('input', function () {
            var start = input.selectionStart, end = input.selectionEnd;
            var v = input.value.toUpperCase().replace(/\s+/g, '');
            if (v !== input.value) { input.value = v; try { input.setSelectionRange(start, end); } catch (e) { /* ignore */ } }
        });
    });

    // ── Amount shorthand ──
    // Arithmetic for "=…": + - * / and brackets. A tiny parser instead of eval, which the CSP forbids.
    function calc(src) {
        var i = 0;
        function peek() { return src.charAt(i); }
        function number() {
            var m = src.slice(i).match(/^[0-9]*\.?[0-9]+/);
            if (!m) throw 0;
            i += m[0].length;
            return parseFloat(m[0]);
        }
        function factor() {
            if (peek() === '-') { i++; return -factor(); }
            if (peek() === '(') { i++; var v = expr(); if (peek() !== ')') throw 0; i++; return v; }
            return number();
        }
        function term() {
            var v = factor();
            while (peek() === '*' || peek() === '/') { var op = src.charAt(i++); var r = factor(); v = op === '*' ? v * r : v / r; }
            return v;
        }
        function expr() {
            var v = term();
            while (peek() === '+' || peek() === '-') { var op = src.charAt(i++); var r = term(); v = op === '+' ? v + r : v - r; }
            return v;
        }
        try { var result = expr(); return i === src.length ? result : null; } catch (e) { return null; }
    }
    function parseAmount(text) {
        var s = String(text).trim().toLowerCase().replace(/[₹,\s]/g, '');
        if (!s) return '';
        if (s.charAt(0) === '=') {
            var expr = s.slice(1);
            var r = calc(expr);
            return r === null || !isFinite(r) ? null : Math.round(r * 100) / 100;
        }
        var m = s.match(/^(-?[0-9]*\.?[0-9]+)(k|l|lac|lakh|lakhs|cr|crore|crores)?$/);
        if (!m) return null;
        var n = parseFloat(m[1]);
        var unit = m[2] || '';
        var mult = unit === 'k' ? 1e3 : (unit.charAt(0) === 'l' ? 1e5 : (unit.indexOf('cr') === 0 ? 1e7 : 1));
        return Math.round(n * mult * 100) / 100;
    }
    document.querySelectorAll('[data-amount]').forEach(function (input) {
        input.setAttribute('title', 'Shorthand works: 25k, 1.5L, 2cr, =1200*3');
        input.addEventListener('blur', function () {
            var v = parseAmount(input.value);
            if (v === null) { input.setCustomValidity('Enter an amount, like 25000, 25k or 1.5L'); input.reportValidity(); return; }
            input.setCustomValidity('');
            if (v !== '') input.value = String(v);
        });
    });

    // ── Checkbox reveals ──
    document.querySelectorAll('input[type="checkbox"][data-reveal]').forEach(function (box) {
        var target = document.querySelector(box.getAttribute('data-reveal'));
        if (!target) return;
        function sync() { target.hidden = !box.checked; }
        box.addEventListener('change', sync);
        sync();
    });

    // ── GSTIN assist ──
    document.querySelectorAll('input[data-gstin]').forEach(function (input) {
        var out = input.parentElement.querySelector('[data-gstin-result]');
        var pan = document.querySelector(input.getAttribute('data-gstin-pan'));
        var state = document.querySelector(input.getAttribute('data-gstin-state'));
        var seq = 0;
        function say(cls, text) { if (out) { out.className = 'field-help ' + cls; out.textContent = text; } }
        var reasons = {
            WrongLength: 'A GSTIN is 15 characters.',
            WrongFormat: "That pattern isn't a GSTIN.",
            UnknownState: "The first two digits aren't a GST state code.",
            ChecksumMismatch: "The last character doesn't match. One character is probably mistyped."
        };
        input.addEventListener('input', function () {
            var v = input.value;
            if (v.length < 15) { say('', v ? (15 - v.length) + ' more to go' : ''); return; }
            var mine = ++seq;
            fetch('/api/core/gstin/' + encodeURIComponent(v), { headers: { Accept: 'application/json' } })
                .then(function (r) { return r.json(); })
                .then(function (d) {
                    if (mine !== seq) return;
                    if (!d.valid) { say('bad', reasons[d.reason] || 'Not a valid GSTIN.'); return; }
                    say('ok', '✓ ' + d.state + ' · PAN ' + d.pan);
                    var ownerUrl = input.getAttribute('data-gstin-owner');
                    if (ownerUrl) {
                        fetch(ownerUrl + encodeURIComponent(v)).then(function (r) { return r.json(); }).then(function (o) {
                            if (mine !== seq || !o) return;
                            out.className = 'field-help bad';
                            out.textContent = 'Already on file as ' + o.name + '. ';
                            var a = document.createElement('a');
                            a.href = o.url; a.textContent = 'Open it →';
                            out.appendChild(a);
                        }).catch(function () { /* the server checks again on save */ });
                    }
                    if (pan && !pan.value) pan.value = d.pan;
                    if (state) state.value = d.stateCode;
                    input.dispatchEvent(new CustomEvent('bme:gstin', { bubbles: true, detail: d }));
                })
                .catch(function () { if (mine === seq) say('', ''); });
        });
    });
})();
