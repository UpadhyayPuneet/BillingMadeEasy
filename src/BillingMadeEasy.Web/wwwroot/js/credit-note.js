// New credit note: a quantity returned fills its value at the invoiced rate, the tax comes back at
// the invoice's rate, and the effect on the invoice is shown before issuing (CreditNoteMath). The
// server works every figure out again; this is the preview.
(function () {
    'use strict';
    var form = document.querySelector('[data-credit-form]');
    if (!form) return;
    var $ = function (sel, root) { return (root || document).querySelector(sel); };
    var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };
    var inr = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', minimumFractionDigits: 2, maximumFractionDigits: 2 });
    var amt = new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    function num(text) {
        var s = String(text || '').trim().toLowerCase().replace(/[₹,\s]/g, '');
        if (!s) return 0;
        var m = s.match(/^([0-9]*\.?[0-9]+)(k|l|lac|lakh|lakhs|cr|crore|crores)?$/);
        if (!m) return 0;
        var u = m[2] || '';
        return parseFloat(m[1]) * (u === 'k' ? 1e3 : u.charAt(0) === 'l' ? 1e5 : u.indexOf('cr') === 0 ? 1e7 : 1);
    }
    function r2(n) { return Math.round((n + Number.EPSILON) * 100) / 100; }
    function attr(el, name) { return parseFloat(el.getAttribute(name)) || 0; }
    function plain(n) { return n ? String(r2(n)) : ''; }

    var inter = form.getAttribute('data-inter') === 'true';
    var roundOff = form.getAttribute('data-round') === 'true';
    var invoiceTotal = attr(form, 'data-invoice-total'), before = attr(form, 'data-credited-before'), balance = attr(form, 'data-balance');
    var invoiceNo = form.getAttribute('data-invoice-number');
    var lines = $$('[data-credit-line]', form);

    function reason() { var r = $('[data-reason]:checked', form); return r ? r.value : ''; }

    function lineAmounts(row) {
        var qtyLeft = attr(row, 'data-qty-left'), left = attr(row, 'data-taxable-left');
        var taxable = r2(num($('[data-taxable]', row).value)), rate = attr(row, 'data-rate');
        var qty = num($('[data-qty]', row).value);
        var problem = qty > qtyLeft + 1e-9 ? 'Only ' + qtyLeft + ' left' : taxable > left + 1e-9 ? 'Only ' + amt.format(left) + ' left' : '';
        var tax = 0;
        if (taxable > 0 && !problem) {
            if (Math.abs(taxable - left) < 0.005) tax = attr(row, 'data-tax-left');
            else if (rate > 0) tax = inter ? r2(taxable * rate / 100) : 2 * r2(taxable * rate / 200);
        }
        return { taxable: problem ? 0 : taxable, tax: tax, problem: problem, left: left };
    }

    function totals() {
        var taxable = 0, tax = 0, settles = true, problems = 0;
        lines.forEach(function (row) {
            var a = lineAmounts(row);
            row.classList.toggle('over', !!a.problem);
            $('[data-f="tax"]', row).textContent = a.problem || (a.taxable ? amt.format(a.tax) : '—');
            $('[data-f="total"]', row).textContent = a.taxable ? amt.format(a.taxable + a.tax) : '—';
            taxable += a.taxable; tax += a.tax;
            if (a.problem) problems++;
            if (a.left > 0 && r2(a.left - a.taxable) > 0) settles = false;
        });
        var sum = r2(taxable + tax), room = r2(invoiceTotal - before);
        var grand = sum === 0 ? 0 : settles ? room : roundOff ? Math.round(sum) : sum;
        grand = Math.min(grand, room);
        var round = r2(grand - sum);

        $('[data-t="taxable"]', form).textContent = inr.format(taxable);
        if (inter) $('[data-t="igst"]', form).textContent = inr.format(tax);
        else { $('[data-t="cgst"]', form).textContent = inr.format(tax / 2); $('[data-t="sgst"]', form).textContent = inr.format(tax / 2); }
        $('[data-t="round"]', form).hidden = $('[data-roundoff-label]', form).hidden = round === 0;
        $('[data-t="round"]', form).textContent = (round > 0 ? '+' : '') + amt.format(round);
        $('[data-t="grand"]', form).textContent = inr.format(grand);

        var off = Math.min(grand, balance), credit = r2(grand - off), effect = '';
        if (problems) effect = 'Some lines ask for more than is left on the invoice.';
        else if (grand > 0) {
            if (off > 0) effect = inr.format(off) + ' comes off ' + invoiceNo + ' (owed ' + inr.format(balance) + ' → ' + inr.format(r2(balance - off)) + '). ';
            if (credit > 0) effect += inr.format(credit) + ' becomes the customer’s credit, to apply to another invoice or refund.';
        }
        var el = $('[data-t="effect"]', form);
        el.textContent = effect;
        el.classList.toggle('bad', problems > 0);
    }

    // A quantity fills in its value; a value typed by hand is left alone after that.
    function fromQty(row) {
        var t = $('[data-taxable]', row);
        var qty = num($('[data-qty]', row).value), qtyLeft = attr(row, 'data-qty-left'), left = attr(row, 'data-taxable-left');
        if (t.getAttribute('data-typed') === 'true') return;
        if (!qty) { t.value = ''; return; }
        t.value = plain(Math.abs(qty - qtyLeft) < 1e-9 ? left : Math.min(r2(attr(row, 'data-unit') * qty), left));
    }

    form.addEventListener('input', function (e) {
        var row = e.target.closest('[data-credit-line]');
        if (row && e.target.matches('[data-qty]')) fromQty(row);
        if (row && e.target.matches('[data-taxable]')) e.target.setAttribute('data-typed', e.target.value ? 'true' : 'false');
        totals();
    });

    $('[data-credit-all]', form).addEventListener('click', function () {
        var returning = reason() === '1';
        lines.forEach(function (row) {
            var q = $('[data-qty]', row), t = $('[data-taxable]', row);
            if (q.disabled) return;
            q.value = returning ? String(attr(row, 'data-qty-left')) : '';
            t.value = plain(attr(row, 'data-taxable-left'));
            t.setAttribute('data-typed', 'false');
        });
        totals();
    });
    $('[data-credit-clear]', form).addEventListener('click', function () {
        lines.forEach(function (row) { $('[data-qty]', row).value = ''; var t = $('[data-taxable]', row); t.value = ''; t.setAttribute('data-typed', 'false'); });
        totals();
    });

    function syncReason() {
        var r = reason();
        var help = $('[data-help-return]', form);
        help.textContent = r === '1'
            ? 'Enter the quantity that came back; its value fills in at the invoiced rate. Tax comes back at the invoice’s rate.'
            : 'Enter the value being taken off each line, before GST. Leave the quantity empty unless the quantity billed was wrong.';
        $('[data-reason-optional]', form).hidden = r === '7';
        // The first useful field for the reason gets the cursor when the reason changes.
        return r;
    }
    $$('[data-reason]', form).forEach(function (el) { el.addEventListener('change', function () { syncReason(); totals(); }); });

    // Enter moves down the column, like a ledger.
    form.addEventListener('keydown', function (e) {
        if (e.key !== 'Enter' || e.ctrlKey || e.metaKey || !e.target.matches('[data-qty], [data-taxable]')) return;
        e.preventDefault();
        var col = e.target.matches('[data-qty]') ? '[data-qty]' : '[data-taxable]';
        var list = $$(col, form).filter(function (el) { return !el.disabled; }), i = list.indexOf(e.target);
        (list[i + 1] || form.querySelector('button[type="submit"]')).focus();
    });

    // After a failed issue: a value that isn't what its quantity gives was typed by hand.
    lines.forEach(function (row) {
        var t = $('[data-taxable]', row), typed = t.value;
        if (!typed) return;
        t.setAttribute('data-typed', 'false');
        fromQty(row);
        if (r2(num(t.value)) !== r2(num(typed))) { t.value = typed; t.setAttribute('data-typed', 'true'); }
    });
    syncReason();
    totals();
    var first = $$('[data-qty]', form).filter(function (el) { return !el.disabled; })[0];
    if (first && !$('.field-error:not(:empty)', form)) first.focus();
})();
