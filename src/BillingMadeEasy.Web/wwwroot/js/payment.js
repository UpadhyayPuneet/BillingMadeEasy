// Record a payment: find the customer, see what they owe, and let the amount settle the oldest
// invoices first (PaymentAllocator.Oldest) unless you split it yourself. TDS per invoice counts as
// paid without using money. The server checks every figure again.
(function () {
    'use strict';
    var form = document.querySelector('[data-payment-form]');
    if (!form) return;
    var $ = function (sel, root) { return (root || document).querySelector(sel); };
    var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };
    var inr = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', minimumFractionDigits: 2, maximumFractionDigits: 2 });
    function amount(text) {
        var s = String(text || '').trim().toLowerCase().replace(/[₹,\s]/g, '');
        if (!s) return 0;
        var m = s.match(/^([0-9]*\.?[0-9]+)(k|l|lac|lakh|lakhs|cr|crore|crores)?$/);
        if (!m) return 0;
        var u = m[2] || '';
        return parseFloat(m[1]) * (u === 'k' ? 1e3 : u.charAt(0) === 'l' ? 1e5 : u.indexOf('cr') === 0 ? 1e7 : 1);
    }
    function r2(n) { return Math.round((n + Number.EPSILON) * 100) / 100; }
    function plain(n) { return n ? String(r2(n)) : ''; }

    var total = $('[data-pay-amount]', form), rowsBox = $('[data-open-rows]', form);
    var manual = false;

    // ── Allocation ──
    function rows() { return $$('[data-alloc]', rowsBox); }
    // The invoice the payment was started from goes first; the rest oldest first.
    function ordered() {
        var all = rows();
        var pinned = function (r) { return r.getAttribute('data-pinned') === 'true'; };
        return all.filter(pinned).concat(all.filter(function (r) { return !pinned(r); }));
    }
    function oldestFirst() {
        var left = amount(total.value);
        ordered().forEach(function (row) {
            var balance = parseFloat(row.getAttribute('data-balance')) || 0;
            var tds = Math.min(amount($('[data-tds]', row).value), balance);
            var take = Math.max(0, Math.min(balance - tds, left));
            $('[data-apply]', row).value = plain(take);
            left = r2(left - take);
        });
        manual = false;
        totals();
    }
    function totals() {
        var applied = 0, tds = 0, over = [];
        rows().forEach(function (row) {
            var balance = parseFloat(row.getAttribute('data-balance')) || 0;
            var a = amount($('[data-apply]', row).value), t = amount($('[data-tds]', row).value);
            applied += a; tds += t;
            row.classList.toggle('over', r2(a + t) > balance);
            if (r2(a + t) > balance) over.push($('[data-f="number"], strong', row).textContent);
        });
        var received = amount(total.value);
        var advance = r2(received - applied);
        $('[data-t="applied"]', form).textContent = inr.format(applied);
        $('[data-t="tds"]', form).textContent = inr.format(tds);
        $('[data-t="advance"]', form).textContent = inr.format(Math.max(0, advance));
        $('[data-t="over"]', form).textContent =
            advance < 0 ? 'The invoices take ' + inr.format(applied) + ', more than the ' + inr.format(received) + ' received.'
            : over.length ? 'More than the balance on ' + over.join(', ') + '.' : '';
    }
    total.addEventListener('input', function () { if (!manual) oldestFirst(); else totals(); });
    rowsBox.addEventListener('input', function (e) {
        if (e.target.matches('[data-apply]')) manual = true;
        if (e.target.matches('[data-tds]') && !manual) oldestFirst(); else totals();
    });
    $('[data-allocate-oldest]', form).addEventListener('click', oldestFirst);
    $('[data-allocate-clear]', form).addEventListener('click', function () {
        rows().forEach(function (row) { $('[data-apply]', row).value = ''; $('[data-tds]', row).value = ''; });
        manual = true; totals();
    });
    // Enter moves down the column, like a ledger.
    rowsBox.addEventListener('keydown', function (e) {
        if (e.key !== 'Enter' || e.ctrlKey || e.metaKey) return;
        e.preventDefault();
        var col = e.target.matches('[data-tds]') ? '[data-tds]' : '[data-apply]';
        var list = $$(col, rowsBox), i = list.indexOf(e.target);
        (list[i + 1] || form.querySelector('button[type="submit"]')).focus();
    });

    // ── Mode ──
    var mode = $('[data-mode]', form);
    function syncMode() {
        var o = mode.options[mode.selectedIndex];
        $('[data-ref-label]', form).textContent = o.getAttribute('data-ref-label');
        var cheque = $('[data-cheque-only]', form); if (cheque) cheque.hidden = mode.value !== '4';
        var bank = $('[data-bank-only]', form); if (bank) bank.hidden = mode.value === '1';
        $('[data-cash-help]', form).hidden = mode.value !== '1';
    }
    mode.addEventListener('change', syncMode);

    // ── Customer ──
    var input = $('[data-customer-lookup]', form), results = $('[data-customer-results]', form), party = $('[data-party-id]', form);
    var seq = 0, timer = 0, active = -1;
    function buildRows(data) {
        rowsBox.textContent = '';
        var tpl = $('#alloc-row');
        data.invoices.forEach(function (inv, i) {
            var row = tpl.content.firstElementChild.cloneNode(true);
            row.setAttribute('data-balance', inv.balance);
            $$('[data-name]', row).forEach(function (el) { el.name = 'Form.Allocations[' + i + '].' + el.getAttribute('data-name'); });
            $('[data-name="SalesInvoiceId"]', row).value = inv.id;
            $('[data-f="number"]', row).textContent = inv.number;
            $('[data-f="date"]', row).textContent = inv.date;
            var due = $('[data-f="due"]', row);
            if (inv.overdue) { var b = document.createElement('span'); b.className = 'badge warn'; b.textContent = inv.overdue + ' days overdue'; due.appendChild(b); }
            else due.textContent = inv.due || 'On receipt';
            $('[data-f="balance"]', row).textContent = inr.format(inv.balance);
            rowsBox.appendChild(row);
        });
        $('[data-open-wrap]', form).hidden = !data.invoices.length;
        var none = $('[data-no-open]', form);
        none.hidden = !!data.invoices.length;
        none.textContent = 'Nothing outstanding. The whole amount will be kept as an advance.';
        var note = $('[data-advance-note]', form);
        note.hidden = !(data.advance > 0);
        if (data.advance > 0) $('[data-advance-text]', form).textContent = input.value + ' already has ' + inr.format(data.advance) +
            ' paid in advance (' + data.advanceReceipts.join(', ') + '). Open that receipt to apply it to invoices.';
        manual = false;
        if (!total.value) {
            var owed = data.invoices.reduce(function (s, i) { return s + i.balance; }, 0);
            if (owed) total.value = plain(owed);
        }
        oldestFirst();
    }
    function pick(li) {
        results.hidden = true;
        party.value = li.getAttribute('data-id');
        input.value = li.getAttribute('data-name');
        fetch(input.getAttribute('data-open-url') + party.value, { headers: { Accept: 'application/json' } })
            .then(function (r) { return r.json(); }).then(buildRows).then(function () { total.focus(); total.select(); });
    }
    input.addEventListener('input', function () {
        if (party.value) { party.value = ''; buildRows({ invoices: [], advance: 0, advanceReceipts: [] }); $('[data-no-open]', form).textContent = 'A customer not in your list: the payment is kept as received from this name.'; }
        clearTimeout(timer);
        var q = input.value.trim();
        if (!q) { results.hidden = true; return; }
        timer = setTimeout(function () {
            var mine = ++seq;
            fetch(input.getAttribute('data-customer-lookup') + encodeURIComponent(q), { headers: { Accept: 'application/json' } })
                .then(function (r) { return r.json(); })
                .then(function (list) {
                    if (mine !== seq || document.activeElement !== input) return;
                    results.textContent = ''; active = -1;
                    list.forEach(function (c) {
                        var li = document.createElement('li');
                        li.setAttribute('role', 'option'); li.setAttribute('data-id', c.id); li.setAttribute('data-name', c.name);
                        var s = document.createElement('strong'); s.textContent = c.name; li.appendChild(s);
                        if (c.city) { var sub = document.createElement('span'); sub.className = 'sub'; sub.textContent = c.city; li.appendChild(sub); }
                        li.addEventListener('mousedown', function (e) { e.preventDefault(); pick(li); });
                        results.appendChild(li);
                    });
                    results.hidden = !list.length;
                    if (list.length) { active = 0; results.firstChild.setAttribute('aria-selected', 'true'); }
                });
        }, 140);
    });
    input.addEventListener('keydown', function (e) {
        var items = $$('li[data-id]', results);
        if (results.hidden || !items.length) return;
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
            e.preventDefault();
            active = (active + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length;
            items.forEach(function (li, n) { li.setAttribute('aria-selected', n === active ? 'true' : 'false'); });
        } else if (e.key === 'Enter') { e.preventDefault(); pick(items[Math.max(0, active)]); }
        else if (e.key === 'Escape') { e.stopPropagation(); results.hidden = true; }
    });
    input.addEventListener('blur', function () { setTimeout(function () { results.hidden = true; }, 120); });

    syncMode();
    // A re-shown form keeps what was typed; a fresh one allocates.
    if (rows().some(function (r) { return $('[data-apply]', r).value || $('[data-tds]', r).value; })) { manual = true; totals(); } else oldestFirst();
})();
