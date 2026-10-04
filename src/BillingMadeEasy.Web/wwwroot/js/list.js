// Shared list behaviour: search as you type (server-side), arrow keys through rows, Enter to open,
// and single-key actions declared with data-key on links. Works without JavaScript too:
// the search box is a normal GET form and every row has a real link.
(function () {
    'use strict';

    var form = document.querySelector('[data-live-search]');
    var results = document.querySelector('[data-live-results]');
    var input = form ? form.querySelector('input[type="search"]') : null;

    function typing(el) {
        if (!el) return false;
        var tag = el.tagName;
        return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || el.isContentEditable;
    }
    function rows() { return Array.prototype.slice.call(document.querySelectorAll('[data-row-nav] tbody tr[data-href]')); }

    // ── Search as you type ──
    if (form && results && input) {
        var timer = null, seq = 0;
        var url = form.getAttribute('data-live-search');

        function run() {
            var params = new URLSearchParams(new FormData(form));
            if (!params.get('q')) params.delete('q');
            var mine = ++seq;
            fetch(url + '&' + params.toString(), { headers: { 'X-Requested-With': 'fetch' } })
                .then(function (r) { if (!r.ok) throw new Error(r.status); return r.text(); })
                .then(function (html) {
                    if (mine !== seq) return;           // a newer search already went out
                    results.innerHTML = html;
                    var shown = params.toString();
                    history.replaceState(null, '', location.pathname + (shown ? '?' + shown : ''));
                })
                .catch(function () { if (mine === seq) form.submit(); });
        }
        input.addEventListener('input', function () { clearTimeout(timer); timer = setTimeout(run, 180); });
        form.addEventListener('submit', function (e) { e.preventDefault(); clearTimeout(timer); run(); });

        // Put the caret at the end when arriving with a query.
        var len = input.value.length;
        try { input.setSelectionRange(len, len); } catch (e) { /* type=search in some browsers */ }

        input.addEventListener('keydown', function (e) {
            if (e.key === 'ArrowDown') {
                var first = rows()[0];
                if (first) { e.preventDefault(); first.focus(); }
            } else if (e.key === 'Enter' && rows().length === 1) {
                // One match: Enter goes straight to it.
                e.preventDefault();
                location.href = rows()[0].getAttribute('data-href');
            } else if (e.key === 'Escape' && input.value) {
                e.preventDefault();
                input.value = '';
                run();
            }
        });
    }

    // ── Rows: click anywhere, arrows, Enter ──
    document.addEventListener('click', function (e) {
        var tr = e.target.closest && e.target.closest('tr[data-href]');
        if (!tr || e.target.closest('a, button, input, label')) return;
        if (e.ctrlKey || e.metaKey) window.open(tr.getAttribute('data-href'), '_blank');
        else location.href = tr.getAttribute('data-href');
    });

    document.addEventListener('keydown', function (e) {
        var active = document.activeElement;
        var list = rows();
        var i = list.indexOf(active);

        if (i >= 0) {
            if (e.key === 'ArrowDown' || e.key === 'j') { e.preventDefault(); if (list[i + 1]) list[i + 1].focus(); return; }
            if (e.key === 'ArrowUp' || e.key === 'k') {
                e.preventDefault();
                if (i === 0 && input) input.focus(); else if (list[i - 1]) list[i - 1].focus();
                return;
            }
            if (e.key === 'Enter') { e.preventDefault(); location.href = active.getAttribute('data-href'); return; }
            if (e.key === 'Home') { e.preventDefault(); list[0].focus(); return; }
            if (e.key === 'End') { e.preventDefault(); list[list.length - 1].focus(); return; }
        }

        if (e.ctrlKey || e.metaKey || e.altKey || typing(active)) return;
        if (e.key === 'f' && input) { e.preventDefault(); input.focus(); input.select(); return; }

        // Single-key actions declared in the markup: <a data-key="n">
        var target = document.querySelector('[data-key="' + (e.key === '"' ? '\\"' : e.key) + '"]');
        if (target) { e.preventDefault(); target.click(); }
    });
})();
