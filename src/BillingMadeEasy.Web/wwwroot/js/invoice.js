// The invoice editor. Keyboard first: type to find a customer or an item, Enter moves along a row
// and adds a line at the end, totals and GST follow every keystroke. The server recomputes every
// amount on save (InvoiceMath); this mirrors it so what you see is what gets saved.
(function () {
    'use strict';
    var form = document.querySelector('[data-invoice-form]');
    if (!form) return;
    var $ = function (sel, root) { return (root || document).querySelector(sel); };
    var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };
    var data = JSON.parse($('#invoice-data').textContent);
    var linesBox = $('[data-lines]', form);
    var template = $('#line-template');
    var inr = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', minimumFractionDigits: 2, maximumFractionDigits: 2 });

    // ── Numbers ──
    function amount(text) {
        var s = String(text || '').trim().toLowerCase().replace(/[₹,\s]/g, '');
        if (!s) return null;
        var m = s.match(/^([0-9]*\.?[0-9]+)(k|l|lac|lakh|lakhs|cr|crore|crores)?$/);
        if (!m) return null;
        var unit = m[2] || '';
        var mult = unit === 'k' ? 1e3 : (unit.charAt(0) === 'l' ? 1e5 : (unit.indexOf('cr') === 0 ? 1e7 : 1));
        return parseFloat(m[1]) * mult;
    }
    function r2(n) { return Math.sign(n) * Math.round((Math.abs(n) + Number.EPSILON) * 100) / 100; }

    // ── Who sells, where it goes: CGST+SGST or IGST ──
    function profile() {
        var el = $('[data-profile]', form);
        var id = el ? String(el.value) : '';
        return data.profiles.filter(function (p) { return String(p.id) === id; })[0] || data.profiles[0] || {};
    }
    function placeOfSupply() {
        var place = $('[data-place]', form).value;
        if (place) return place;
        var ship = $('[name="Form.ShipElsewhere"][type="checkbox"]', form);
        if (ship && ship.checked && $('[data-ship-state]', form).value) return $('[data-ship-state]', form).value;
        return $('[data-buyer-state]', form).value || profile().state || '';
    }
    function stateName(code) {
        var o = $('[data-buyer-state] option[value="' + code + '"]', form);
        return o ? o.textContent : code;
    }

    // ── Line arithmetic (InvoiceMath.Line) ──
    function lineAmounts(line, inter, noTax) {
        var qty = amount($('[data-qty]', line).value) || 0;
        var rate = amount($('[data-rate]', line).value) || 0;
        var disc = amount($('[data-disc]', line).value) || 0;
        var incl = $('[data-incl]', line).checked;
        var pure = line.hasAttribute('data-pure');
        var sel = $('[data-tax]', line);
        var pct = noTax || pure ? 0 : parseFloat(sel.options[sel.selectedIndex].getAttribute('data-rate')) || 0;
        var gross = r2(qty * rate), discount = r2(gross * disc / 100), net = gross - discount;
        var cgst = 0, sgst = 0, igst = 0, taxable;
        if (incl && pct > 0) {
            var inside = net - net * 100 / (100 + pct);
            if (inter) igst = r2(inside); else { cgst = r2(inside / 2); sgst = cgst; }
            taxable = net - cgst - sgst - igst;
        } else {
            taxable = net;
            if (inter) igst = r2(taxable * pct / 100); else { cgst = r2(taxable * pct / 200); sgst = cgst; }
        }
        return { taxable: r2(taxable), cgst: cgst, sgst: sgst, igst: igst, total: r2(taxable + cgst + sgst + igst), pure: pure, blank: !qty && !rate };
    }

    // ── Amount in words (AmountInWords.Rupees) ──
    var ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen',
        'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    var tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    function below100(n) { return n < 20 ? ones[n] : tens[Math.floor(n / 10)] + (n % 10 ? ' ' + ones[n % 10] : ''); }
    function whole(n) {
        var parts = [], crore = Math.floor(n / 1e7); n %= 1e7;
        var lakh = Math.floor(n / 1e5); n %= 1e5;
        var thousand = Math.floor(n / 1e3); n %= 1e3;
        var hundred = Math.floor(n / 100); n %= 100;
        if (crore) parts.push(whole(crore) + ' Crore');
        if (lakh) parts.push(below100(lakh) + ' Lakh');
        if (thousand) parts.push(below100(thousand) + ' Thousand');
        if (hundred) parts.push(ones[hundred] + ' Hundred');
        if (n) parts.push(below100(n));
        return parts.join(' ');
    }
    function words(x) {
        x = r2(x);
        var rupees = Math.floor(x), paise = Math.round((x - rupees) * 100);
        return 'Rupees ' + (rupees ? whole(rupees) : 'Zero') + (paise ? ' and ' + below100(paise) + ' Paise' : '') + ' Only';
    }

    // ── Totals ──
    var show = function (key, value) { var el = $('[data-t="' + key + '"]', form); if (el) el.textContent = value; };
    var toggle = function (attr, on) { $$('[' + attr + ']', form).forEach(function (el) { el.hidden = !on; }); };
    function recalc() {
        var p = profile(), place = placeOfSupply();
        var inter = !!(p.state && place && p.state !== place);
        var noTax = !!p.composition;
        var t = { taxable: 0, cgst: 0, sgst: 0, igst: 0, reimb: 0 };
        $$('[data-line]', linesBox).forEach(function (line) {
            var a = lineAmounts(line, inter, noTax);
            $('[data-line-total]', line).textContent = a.blank ? '' : inr.format(a.total);
            if (a.pure) t.reimb += a.total;
            else { t.taxable += a.taxable; t.cgst += a.cgst; t.sgst += a.sgst; t.igst += a.igst; }
        });
        var before = r2(t.taxable + t.cgst + t.sgst + t.igst + t.reimb);
        var grand = data.roundOff ? Math.round(before) : before;
        var round = r2(grand - before);
        show('taxable', inr.format(t.taxable));
        show('cgst', inr.format(t.cgst)); show('sgst', inr.format(t.sgst)); show('igst', inr.format(t.igst));
        show('reimb', inr.format(t.reimb)); show('round', (round > 0 ? '+' : '') + inr.format(round));
        show('grand', inr.format(grand));
        show('words', grand > 0 ? words(grand) : '');
        toggle('data-intra', !inter && !noTax); toggle('data-inter', inter && !noTax);
        toggle('data-reimb', t.reimb > 0); toggle('data-round', round !== 0);

        var mode = $('[data-tax-mode]', form);
        if (mode) {
            mode.className = 'tax-mode ' + (inter ? 'inter' : 'intra');
            mode.textContent = noTax ? 'Composition scheme: no GST is charged (bill of supply)'
                : !p.state ? 'Set your business state under Your business'
                : inter ? stateName(p.state) + ' → ' + stateName(place) + ': IGST'
                : 'Within ' + stateName(p.state) + ': CGST + SGST';
        }
        var auto = $('[data-place-auto]', form);
        if (auto) auto.hidden = !!$('[data-place]', form).value;
    }

    // ── Lines: add, remove, number ──
    function renumber() {
        $$('[data-line]', linesBox).forEach(function (line, i) {
            $('[data-ln]', line).textContent = i + 1;
            $$('[name]', line).forEach(function (el) { el.name = el.name.replace(/Lines\[(\d+|__i__)\]/, 'Lines[' + i + ']'); });
        });
    }
    function addLine(focus) {
        var line = template.content.firstElementChild.cloneNode(true);
        linesBox.appendChild(line);
        wireLine(line);
        renumber();
        if (focus) $('[data-item-lookup]', line).focus();
        return line;
    }
    function removeLine(line) {
        var lines = $$('[data-line]', linesBox);
        var next = lines[lines.indexOf(line) + 1] || lines[lines.indexOf(line) - 1];
        if (lines.length === 1) addLine(false);
        line.remove();
        renumber(); recalc();
        if (next && document.body.contains(next)) $('[data-item-lookup]', next).focus();
    }
    $('[data-add-line]', form).addEventListener('click', function () { addLine(true); });

    // Enter moves to the next cell; from the last cell of the last line it adds a line.
    function cells(line) { return $$('input:not([type="hidden"]):not([type="checkbox"]), select', line); }
    function nextCell(from) {
        var line = from.closest('[data-line]');
        var list = cells(line), i = list.indexOf(from);
        if (i < list.length - 1) { list[i + 1].focus(); if (list[i + 1].select) list[i + 1].select(); return; }
        var lines = $$('[data-line]', linesBox), after = lines[lines.indexOf(line) + 1];
        (after ? $('[data-item-lookup]', after) : $('[data-item-lookup]', addLine(false))).focus();
    }

    // ── Item lookup on a line ──
    function partyId() { return $('[data-party-id]', form).value; }
    function wireLine(line) {
        var input = $('[data-item-lookup]', line), results = $('[data-item-results]', line), hint = $('[data-price-hint]', line);
        var seq = 0, timer = 0, active = -1;
        var list = function () { return $$('li[data-id]', results); };
        var highlight = function (i) {
            var items = list(); if (!items.length) return;
            active = (i + items.length) % items.length;
            items.forEach(function (li, n) { li.setAttribute('aria-selected', n === active ? 'true' : 'false'); });
        };
        var choose = function (id) {
            results.hidden = true;
            var qty = amount($('[data-qty]', line).value) || 1;
            var url = '/Sales/Invoices/Edit?handler=Item&offeringId=' + id + '&qty=' + qty + '&date=' + encodeURIComponent($('[data-invoice-date]', form).value) +
                      (partyId() ? '&partyId=' + partyId() : '');
            fetch(url, { headers: { Accept: 'application/json' } }).then(function (r) { return r.json(); }).then(function (it) {
                $('[data-offering]', line).value = it.id;
                input.value = it.name;
                $('[data-hsn]', line).value = it.hsn || '';
                $('[data-unit]', line).value = it.unit || '';
                if (!$('[data-qty]', line).value) $('[data-qty]', line).value = '1';
                if (it.price !== null && it.price !== undefined) $('[data-rate]', line).value = String(+it.price);
                $('[data-incl]', line).checked = !!it.inclusive;
                $('[data-source]', line).value = it.source || '';
                var tax = $('[data-tax]', line);
                if (it.pureAgent) { line.setAttribute('data-pure', ''); tax.value = ''; tax.disabled = true; }
                else {
                    line.removeAttribute('data-pure'); tax.disabled = false;
                    if (it.taxRateId && $('option[value="' + it.taxRateId + '"]', tax)) tax.value = String(it.taxRateId);
                    else if (it.taxRateId) tax.value = '';
                }
                var parts = [];
                if (it.pureAgent) parts.push('Reimbursement at cost · outside GST');
                else if (it.source && it.source !== 'Standard price') parts.push(it.source + (it.standard ? ' (standard ' + inr.format(it.standard) + ')' : ''));
                if (it.lastPrice) parts.push('Last sold ' + inr.format(it.lastPrice) + ' on ' + it.lastOn + (it.lastInvoice ? ' · ' + it.lastInvoice : ''));
                if (it.taxRateId && !it.pureAgent && !tax.value) parts.push("The item's GST rate isn't valid on this date. Choose the current one.");
                hint.textContent = parts.join(' · ');
                recalc();
                var q = $('[data-qty]', line); q.focus(); q.select();
            }).catch(function () { hint.textContent = "Couldn't load that item. Try again."; });
        };
        input.addEventListener('input', function () {
            clearTimeout(timer);
            if (!input.value.trim()) { $('[data-offering]', line).value = ''; hint.textContent = ''; results.hidden = true; return; }
            timer = setTimeout(function () {
                var mine = ++seq;
                fetch('/Sales/Invoices/Edit?handler=Items&q=' + encodeURIComponent(input.value.trim()) + (partyId() ? '&partyId=' + partyId() : ''),
                      { headers: { Accept: 'application/json' } })
                    .then(function (r) { return r.json(); })
                    .then(function (rows) {
                        // A late answer for a field the person has already left stays closed.
                        if (mine !== seq || document.activeElement !== input) return;
                        results.textContent = ''; active = -1;
                        rows.forEach(function (it) {
                            var li = document.createElement('li');
                            li.setAttribute('role', 'option'); li.setAttribute('data-id', it.offeringId);
                            var s = document.createElement('strong'); s.textContent = it.offeringName; li.appendChild(s);
                            var sub = document.createElement('span'); sub.className = 'sub';
                            sub.textContent = [it.boughtBefore ? 'bought before' : null, it.brandName, it.hsnSacCode, it.taxName,
                                it.defaultPrice !== null ? inr.format(it.defaultPrice) + (it.unitCode ? ' / ' + it.unitCode : '') : null].filter(Boolean).join(' · ');
                            li.appendChild(sub);
                            li.addEventListener('mousedown', function (e) { e.preventDefault(); choose(it.offeringId); });
                            results.appendChild(li);
                        });
                        if (!rows.length) {
                            var none = document.createElement('li'); none.className = 'none';
                            none.textContent = 'Not in the catalogue — fine for a one-off line. Fill in HSN/SAC, rate and GST.';
                            results.appendChild(none);
                        }
                        results.hidden = false;
                        if (rows.length) highlight(0);
                    }).catch(function () { results.hidden = true; });
            }, 140);
        });
        input.addEventListener('keydown', function (e) {
            if (!results.hidden && list().length) {
                if (e.key === 'ArrowDown') { e.preventDefault(); highlight(active + 1); return; }
                if (e.key === 'ArrowUp') { e.preventDefault(); highlight(active - 1); return; }
                if (e.key === 'Enter' && active >= 0) { e.preventDefault(); e.stopPropagation(); choose(list()[active].getAttribute('data-id')); return; }
            }
            if (e.key === 'Escape' && !results.hidden) { e.stopPropagation(); results.hidden = true; }
        });
        input.addEventListener('blur', function () { setTimeout(function () { results.hidden = true; }, 120); });

        line.addEventListener('keydown', function (e) {
            if (e.altKey && (e.key === 'Delete' || e.key === 'Backspace')) { e.preventDefault(); removeLine(line); return; }
            if (e.key === 'Enter' && !e.ctrlKey && !e.metaKey && !e.shiftKey && e.target.matches('input, select')) {
                if (e.target === input && !results.hidden && list().length) return;
                e.preventDefault();
                nextCell(e.target);
            }
        });
        line.addEventListener('input', recalc);
        line.addEventListener('change', recalc);
        $('[data-remove-line]', line).addEventListener('click', function () { removeLine(line); });
    }
    $$('[data-line]', linesBox).forEach(wireLine);
    renumber();

    // ── Customer ──
    var customer = $('[data-customer-lookup]', form);
    var custResults = $('[data-customer-results]', form), custHelp = $('[data-customer-help]', form);
    var partyField = $('[data-party-id]', form), branch = $('[data-branch]', form), branchField = $('[data-branch-field]', form);
    var gstinShow = $('[data-buyer-gstin-show]', form), address = $('[data-buyer-address]', form), buyerState = $('[data-buyer-state]', form);
    var cSeq = 0, cTimer = 0, cActive = -1;
    function walkIn(on) { $$('[data-walkin-only]', form).forEach(function (el) { el.hidden = !on; }); }
    function applyBranch() {
        var o = branch.options[branch.selectedIndex];
        if (!o) return;
        gstinShow.textContent = o.getAttribute('data-gstin') ? 'GSTIN ' + o.getAttribute('data-gstin') : 'Unregistered';
        if (o.getAttribute('data-state')) buyerState.value = o.getAttribute('data-state');
        if (o.getAttribute('data-address')) address.value = o.getAttribute('data-address');
        recalc();
    }
    branch.addEventListener('change', applyBranch);
    function pickCustomer(id) {
        custResults.hidden = true;
        fetch(customer.getAttribute('data-customer-url') + id, { headers: { Accept: 'application/json' } })
            .then(function (r) { return r.json(); })
            .then(function (c) {
                partyField.value = c.id;
                customer.value = c.name;
                walkIn(false);
                custHelp.className = 'field-help' + (c.onHold ? ' bad' : '');
                custHelp.textContent = c.onHold ? c.name + ' is on hold or closed. You can draft, but not issue, until they are active.' : (c.legalName !== c.name ? c.legalName : '');
                branch.textContent = '';
                c.locations.forEach(function (l) {
                    var o = document.createElement('option');
                    o.value = l.id; o.textContent = l.name + (l.gstin ? ' · ' + l.gstin : '');
                    o.setAttribute('data-state', l.stateCode || ''); o.setAttribute('data-gstin', l.gstin || ''); o.setAttribute('data-address', l.address || '');
                    if (l.isDefault) o.selected = true;
                    branch.appendChild(o);
                });
                branchField.hidden = c.locations.length < 2;
                if (c.address) address.value = c.address;
                if (c.stateCode) buyerState.value = c.stateCode;
                if (c.locations.length) applyBranch(); else { gstinShow.textContent = 'Unregistered'; recalc(); }
                // Items already picked may have an agreed price for this customer: refresh them.
                $$('[data-line]', linesBox).forEach(function (line) {
                    var oid = $('[data-offering]', line).value;
                    if (oid) line.dispatchEvent(new CustomEvent('bme:reprice', { detail: oid, bubbles: true }));
                });
                var first = $('[data-line] [data-item-lookup]', linesBox);
                if (first && !first.value) first.focus();
            });
    }
    customer.addEventListener('input', function () {
        if (partyField.value) {
            // Typing over a chosen customer starts again: it's a walk-in until another is picked.
            partyField.value = ''; branch.textContent = ''; branchField.hidden = true; gstinShow.textContent = ''; walkIn(true);
            custHelp.className = 'field-help'; custHelp.textContent = "Not in your list? Just type the name — it's billed as a walk-in customer.";
        }
        clearTimeout(cTimer);
        var q = customer.value.trim();
        if (!q) { custResults.hidden = true; return; }
        cTimer = setTimeout(function () {
            var mine = ++cSeq;
            fetch(customer.getAttribute('data-customer-lookup') + encodeURIComponent(q), { headers: { Accept: 'application/json' } })
                .then(function (r) { return r.json(); })
                .then(function (rows) {
                    if (mine !== cSeq || document.activeElement !== customer) return;
                    custResults.textContent = ''; cActive = -1;
                    rows.forEach(function (c) {
                        var li = document.createElement('li');
                        li.setAttribute('role', 'option'); li.setAttribute('data-id', c.id);
                        var s = document.createElement('strong'); s.textContent = c.name; li.appendChild(s);
                        var sub = document.createElement('span'); sub.className = 'sub';
                        sub.textContent = [c.city, c.onHold ? 'on hold' : null].filter(Boolean).join(' · ');
                        li.appendChild(sub);
                        li.addEventListener('mousedown', function (e) { e.preventDefault(); pickCustomer(c.id); });
                        custResults.appendChild(li);
                    });
                    var walk = document.createElement('li'); walk.className = 'none';
                    walk.textContent = rows.length ? 'Or keep typing for a walk-in customer' : 'No saved customer matches — billed as walk-in “' + q + '”';
                    custResults.appendChild(walk);
                    custResults.hidden = false;
                    var items = $$('li[data-id]', custResults);
                    if (items.length) { cActive = 0; items[0].setAttribute('aria-selected', 'true'); }
                });
        }, 140);
    });
    customer.addEventListener('keydown', function (e) {
        var items = $$('li[data-id]', custResults);
        if (custResults.hidden || !items.length) {
            if (e.key === 'Enter') { e.preventDefault(); custResults.hidden = true; var f = $('[data-line] [data-item-lookup]', linesBox); if (f) f.focus(); }
            return;
        }
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
            e.preventDefault();
            cActive = (cActive + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length;
            items.forEach(function (li, n) { li.setAttribute('aria-selected', n === cActive ? 'true' : 'false'); });
        } else if (e.key === 'Enter') { e.preventDefault(); pickCustomer(items[Math.max(0, cActive)].getAttribute('data-id')); }
        else if (e.key === 'Escape') { e.stopPropagation(); custResults.hidden = true; }
    });
    customer.addEventListener('blur', function () { setTimeout(function () { custResults.hidden = true; }, 120); });
    if (partyField.value) {
        walkIn(false);
        // Opened from a customer's page: bring in their branch, address and state straight away.
        if (!address.value.trim()) pickCustomer(partyField.value);
    }

    // Re-price a line when the customer changes (agreed prices differ per customer).
    linesBox.addEventListener('bme:reprice', function (e) {
        var line = e.target.closest('[data-line]');
        var url = '/Sales/Invoices/Edit?handler=Item&offeringId=' + e.detail + '&qty=' + (amount($('[data-qty]', line).value) || 1) + '&partyId=' + partyId();
        fetch(url, { headers: { Accept: 'application/json' } }).then(function (r) { return r.json(); }).then(function (it) {
            if (it.price === null || it.price === undefined) return;
            var rate = $('[data-rate]', line);
            if (+rate.value !== +it.price) {
                rate.value = String(+it.price);
                $('[data-source]', line).value = it.source || '';
                $('[data-price-hint]', line).textContent = (it.source || 'Price') + ' for this customer' + (it.lastPrice ? ' · last sold ' + inr.format(it.lastPrice) + ' on ' + it.lastOn : '');
                recalc();
            }
        });
    });

    // ── Dates ──
    var invDate = $('[data-invoice-date]', form), due = $('[data-due-date]', form);
    $$('[data-due-days]', form).forEach(function (b) {
        b.addEventListener('click', function () {
            var d = parseInt(b.getAttribute('data-due-days'), 10);
            if (!d) { due.value = ''; return; }
            var base = invDate.value ? new Date(invDate.value + 'T00:00:00') : new Date();
            base.setDate(base.getDate() + d);
            due.value = base.getFullYear() + '-' + String(base.getMonth() + 1).padStart(2, '0') + '-' + String(base.getDate()).padStart(2, '0');
        });
    });

    // ── Anything that moves the place of supply or the seller ──
    ['[data-place]', '[data-buyer-state]', '[data-ship-state]', '[data-profile]', '[name="Form.ShipElsewhere"]'].forEach(function (sel) {
        var el = $(sel, form); if (el) el.addEventListener('change', recalc);
    });
    form.addEventListener('bme:gstin', recalc);

    // Ctrl+Shift+Enter: save and issue (Ctrl+Enter alone saves a draft, via form.js).
    document.addEventListener('keydown', function (e) {
        if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'Enter') {
            var issue = $('[data-issue]', form);
            if (!issue) return;
            e.preventDefault(); e.stopImmediatePropagation();
            form.requestSubmit(issue);
        }
    }, true);

    // Blank trailing lines are not errors; drop them before posting so numbering stays tidy.
    form.addEventListener('submit', function () {
        var lines = $$('[data-line]', linesBox);
        lines.forEach(function (line) {
            var blank = !$('[data-offering]', line).value && !$('[data-item-lookup]', line).value.trim() && !$('[data-rate]', line).value.trim();
            if (blank && $$('[data-line]', linesBox).length > 1) line.remove();
        });
        $$('[data-tax]:disabled', linesBox).forEach(function (s) { s.disabled = false; });
        renumber();
    });

    recalc();
})();
