// The catalogue item form: shows only the fields that apply to the chosen type, checks the HSN/SAC
// as it's typed, shows what the customer pays and what you keep, and finds brands and customers.
// The server repeats every check on save; this only gets the answer to the person sooner.
(function () {
    'use strict';

    var form = document.querySelector('[data-item-form]');
    if (!form) return;
    var token = form.querySelector('input[name="__RequestVerificationToken"]');

    function selectedType() {
        var r = form.querySelector('[data-type-radio]:checked');
        return r ? r.value : '1';
    }

    // ── Type: product, service or expense ──
    var pureAgent = form.querySelector('[data-pure-agent]');
    function syncType() {
        var type = selectedType();
        form.querySelectorAll('[data-for-type]').forEach(function (el) {
            el.hidden = el.getAttribute('data-for-type').split(',').indexOf(type) < 0;
        });
        if (pureAgent && type !== '2' && pureAgent.checked) { pureAgent.checked = false; syncPureAgent(); }
        checkHsn();
    }
    form.querySelectorAll('[data-type-radio]').forEach(function (r) { r.addEventListener('change', syncType); });

    // ── HSN / SAC ── mirrors Core.Tax.Hsn.Problem
    var hsn = form.querySelector('[data-hsn]');
    var hsnHelp = form.querySelector('[data-hsn-help]');
    var hsnDefault = hsnHelp ? hsnHelp.textContent : '';
    function hsnProblem(code, isService) {
        if (!code) return null;
        if (isService) {
            if (code.indexOf('99') !== 0) return 'Service codes (SAC) start with 99, e.g. 998361.';
            if (code.length !== 6) return 'A SAC is 6 digits, e.g. 998361.';
            return null;
        }
        if (code.indexOf('99') === 0 && code.length === 6) return 'Codes starting 99 are for services. Goods use an HSN code.';
        if ([4, 6, 8].indexOf(code.length) < 0) return 'An HSN code is 4, 6 or 8 digits.';
        return null;
    }
    function checkHsn() {
        if (!hsn || !hsnHelp) return;
        var code = hsn.value.replace(/\D/g, '');
        var isService = selectedType() === '2';
        if (!code) { hsnHelp.className = 'field-help'; hsnHelp.textContent = hsnDefault; return; }
        var problem = hsnProblem(code, isService);
        // Only complain once they've typed enough to be judged, or left the field.
        var settled = document.activeElement !== hsn || code.length >= 8 || (isService && code.length >= 6);
        if (problem && settled) { hsnHelp.className = 'field-help bad'; hsnHelp.textContent = problem; }
        else if (!problem) {
            hsnHelp.className = 'field-help ok';
            hsnHelp.textContent = isService ? 'Valid SAC.' : code.length >= 6 ? 'Valid HSN. Fine for e-invoices.' : 'Valid HSN. E-invoices need 6 digits.';
        } else { hsnHelp.className = 'field-help'; hsnHelp.textContent = hsnDefault; }
    }
    if (hsn) {
        hsn.addEventListener('input', function () {
            var digits = hsn.value.replace(/\D/g, '');
            if (digits !== hsn.value) hsn.value = digits;
            checkHsn();
        });
        hsn.addEventListener('blur', checkHsn);
    }

    // ── Pure agent: outside GST, so no rate ──
    var taxSelect = form.querySelector('[data-tax-select]');
    function syncPureAgent() {
        if (!taxSelect || !pureAgent) return;
        taxSelect.disabled = pureAgent.checked;
        var holder = form.querySelector('[data-gst-rate]');
        if (holder) holder.classList.toggle('muted-field', pureAgent.checked);
        updatePrice();
    }
    if (pureAgent) pureAgent.addEventListener('change', syncPureAgent);

    // ── Price breakup and margin ── mirrors Core.Billing.PriceMath
    var price = form.querySelector('[data-price]');
    var cost = form.querySelector('[data-cost]');
    var breakup = form.querySelector('[data-price-breakup]');
    var marginOut = form.querySelector('[data-margin]');
    var inr = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', minimumFractionDigits: 2, maximumFractionDigits: 2 });

    function amount(text) {
        var s = String(text || '').trim().toLowerCase().replace(/[₹,\s]/g, '');
        var m = s.match(/^([0-9]*\.?[0-9]+)(k|l|lac|lakh|lakhs|cr|crore|crores)?$/);
        if (!m) return null;
        var unit = m[2] || '';
        var mult = unit === 'k' ? 1e3 : (unit.charAt(0) === 'l' ? 1e5 : (unit.indexOf('cr') === 0 ? 1e7 : 1));
        return Math.round(parseFloat(m[1]) * mult * 100) / 100;
    }
    function round2(n) { return Math.round((n + Number.EPSILON) * 100) / 100; }
    function rate() {
        if (!taxSelect || taxSelect.disabled) return 0;
        var opt = taxSelect.options[taxSelect.selectedIndex];
        return opt ? parseFloat(opt.getAttribute('data-rate')) || 0 : 0;
    }
    function inclusive() {
        var r = form.querySelector('[data-inclusive]:checked');
        return r ? r.value === 'true' : false;
    }
    function split(p, ratePercent, incl) {
        if (incl) { var taxable = round2(p * 100 / (100 + ratePercent)); return { taxable: taxable, tax: round2(p - taxable), total: p }; }
        var tax = round2(p * ratePercent / 100);
        return { taxable: p, tax: tax, total: round2(p + tax) };
    }
    function updatePrice() {
        if (!breakup) return;
        var p = price ? amount(price.value) : null;
        var r = rate();
        var noRate = !pureAgent || !pureAgent.checked ? (taxSelect && !taxSelect.value) : false;
        breakup.textContent = '';
        if (p === null || p === 0) { if (marginOut) marginOut.textContent = ''; return; }
        var s = split(p, r, inclusive());
        if (pureAgent && pureAgent.checked) {
            breakup.textContent = 'Billed at ' + inr.format(p) + ' with no GST — recovered at cost.';
        } else if (noRate) {
            breakup.textContent = 'Choose a GST rate to see what the customer pays.';
        } else {
            breakup.appendChild(part('Taxable value', s.taxable));
            breakup.appendChild(part('GST ' + r + '%', s.tax));
            breakup.appendChild(part('Customer pays', s.total, true));
        }
        if (!marginOut) return;
        var c = cost ? amount(cost.value) : null;
        marginOut.textContent = '';
        marginOut.classList.remove('loss');
        if (c === null) return;
        var profit = round2(s.taxable - c);
        var marginPct = s.taxable === 0 ? null : Math.round((profit / s.taxable) * 1000) / 10;
        var markupPct = c === 0 ? null : Math.round((profit / c) * 1000) / 10;
        marginOut.appendChild(part(profit < 0 ? 'Loss per unit' : 'You keep per unit', Math.abs(profit), true));
        var detail = document.createElement('span');
        detail.className = 'sub';
        detail.textContent = [marginPct === null ? null : 'margin ' + marginPct + '%', markupPct === null ? null : 'markup ' + markupPct + '%'].filter(Boolean).join(' · ');
        marginOut.appendChild(detail);
        if (profit < 0) marginOut.classList.add('loss');
    }
    function part(label, value, strong) {
        var el = document.createElement('span');
        el.className = 'breakup-part' + (strong ? ' strong' : '');
        var l = document.createElement('span'); l.className = 'sub'; l.textContent = label;
        var v = document.createElement('span'); v.className = 'num'; v.textContent = inr.format(value);
        el.appendChild(l); el.appendChild(v);
        return el;
    }
    [price, cost].forEach(function (el) { if (el) { el.addEventListener('input', updatePrice); el.addEventListener('blur', function () { setTimeout(updatePrice, 0); }); } });
    if (taxSelect) taxSelect.addEventListener('change', updatePrice);
    form.querySelectorAll('[data-inclusive]').forEach(function (r) { r.addEventListener('change', updatePrice); });

    // ── Brand: suggest the spelling already used so "MRF" and "M.R.F." don't become two brands ──
    var brand = form.querySelector('[data-brand-lookup]');
    if (brand) {
        var list = document.getElementById(brand.getAttribute('list'));
        var brandHint = form.querySelector('[data-brand-hint]');
        var brandSeq = 0, brandTimer = 0, known = [];
        brand.addEventListener('input', function () {
            clearTimeout(brandTimer);
            var q = brand.value.trim();
            if (brandHint) brandHint.textContent = '';
            if (q.length < 1) return;
            brandTimer = setTimeout(function () {
                var mine = ++brandSeq;
                fetch(brand.getAttribute('data-brand-lookup') + encodeURIComponent(q), { headers: { Accept: 'application/json' } })
                    .then(function (r) { return r.ok ? r.json() : []; })
                    .then(function (rows) {
                        if (mine !== brandSeq) return;
                        known = rows.map(function (b) { return b.brandName; });
                        list.textContent = '';
                        known.forEach(function (name) { var o = document.createElement('option'); o.value = name; list.appendChild(o); });
                        hintBrand();
                    })
                    .catch(function () { /* suggestions only */ });
            }, 180);
        });
        brand.addEventListener('blur', hintBrand);
        function hintBrand() {
            if (!brandHint) return;
            var v = brand.value.trim();
            if (!v) { brandHint.textContent = ''; return; }
            var exact = known.some(function (k) { return k === v; });
            var close = known.filter(function (k) { return k !== v && squash(k) === squash(v); })[0];
            brandHint.className = 'field-help';
            if (exact) brandHint.textContent = 'Existing brand.';
            else if (close) { brandHint.className = 'field-help bad'; brandHint.textContent = 'You already have “' + close + '”. Pick it from the list to keep reports together.'; }
            else if (document.activeElement !== brand) brandHint.textContent = 'New brand — it will be added.';
        }
        function squash(s) { return s.toLowerCase().replace(/[^a-z0-9]/g, ''); }
    }

    // ── Category: add one without leaving the form ──
    var addCategory = form.querySelector('[data-add-category]');
    var categorySelect = form.querySelector('[data-category-select]');
    if (addCategory && categorySelect) {
        addCategory.addEventListener('click', function () {
            var name = window.prompt('New category name');
            if (!name || !name.trim()) return;
            var body = new URLSearchParams();
            body.set('name', name.trim());
            if (token) body.set('__RequestVerificationToken', token.value);
            addCategory.disabled = true;
            fetch(addCategory.getAttribute('data-add-category'), { method: 'POST', body: body, headers: { Accept: 'application/json' } })
                .then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
                .then(function (res) {
                    if (!res.ok) { window.alert(res.d.error || 'That category couldn\'t be added.'); return; }
                    var o = document.createElement('option');
                    o.value = res.d.id; o.textContent = res.d.name;
                    categorySelect.appendChild(o);
                    categorySelect.value = String(res.d.id);
                    categorySelect.dispatchEvent(new Event('change', { bubbles: true }));
                    categorySelect.focus();
                })
                .catch(function () { window.alert('That category couldn\'t be added. Check your connection.'); })
                .then(function () { addCategory.disabled = false; });
        });
    }

    // ── Barcode: scanners end with Enter; don't let that submit the half-filled form ──
    var barcode = form.querySelector('[data-barcode]');
    if (barcode) barcode.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            var next = form.querySelector('[name="Form.PackSize"]');
            if (next) next.focus();
        }
    });

    // ── Customer picker in the customer-price dialog ──
    var lookup = document.querySelector('[data-party-lookup]');
    if (lookup) {
        var dlgForm = lookup.closest('form');
        var partyId = dlgForm.querySelector('[data-party-id]');
        var results = dlgForm.querySelector('[data-party-results]');
        var seq = 0, timer = 0, active = -1;
        function choose(li) {
            lookup.value = li.getAttribute('data-name');
            partyId.value = li.getAttribute('data-id');
            lookup.setCustomValidity('');
            results.hidden = true;
            var next = dlgForm.querySelector('[name="price"]');
            if (next) next.focus();
        }
        function highlight(i) {
            var items = results.querySelectorAll('li');
            if (!items.length) return;
            active = (i + items.length) % items.length;
            items.forEach(function (li, n) { li.setAttribute('aria-selected', n === active ? 'true' : 'false'); });
        }
        lookup.addEventListener('input', function () {
            partyId.value = '';
            clearTimeout(timer);
            var q = lookup.value.trim();
            if (!q) { results.hidden = true; return; }
            timer = setTimeout(function () {
                var mine = ++seq;
                fetch(lookup.getAttribute('data-party-lookup') + encodeURIComponent(q), { headers: { Accept: 'application/json' } })
                    .then(function (r) { return r.ok ? r.json() : []; })
                    .then(function (rows) {
                        if (mine !== seq) return;
                        results.textContent = '';
                        active = -1;
                        if (!rows.length) {
                            var none = document.createElement('li');
                            none.className = 'none';
                            none.textContent = 'No customer matches “' + q + '”.';
                            results.appendChild(none);
                        }
                        rows.forEach(function (p) {
                            var li = document.createElement('li');
                            li.setAttribute('role', 'option');
                            li.setAttribute('data-id', p.id);
                            li.setAttribute('data-name', p.name);
                            var strong = document.createElement('strong'); strong.textContent = p.name;
                            li.appendChild(strong);
                            if (p.city) { var s = document.createElement('span'); s.className = 'sub'; s.textContent = p.city; li.appendChild(s); }
                            li.addEventListener('mousedown', function (e) { e.preventDefault(); choose(li); });
                            results.appendChild(li);
                        });
                        results.hidden = false;
                        if (rows.length) highlight(0);
                    })
                    .catch(function () { results.hidden = true; });
            }, 150);
        });
        lookup.addEventListener('keydown', function (e) {
            if (results.hidden) return;
            if (e.key === 'ArrowDown') { e.preventDefault(); highlight(active + 1); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); highlight(active - 1); }
            else if (e.key === 'Enter') {
                var li = results.querySelectorAll('li[data-id]')[active];
                if (li) { e.preventDefault(); choose(li); }
            }
        });
        lookup.addEventListener('blur', function () { setTimeout(function () { results.hidden = true; }, 100); });
        dlgForm.querySelectorAll('[name="price"], [name="discountPercent"]').forEach(function (el) {
            el.addEventListener('input', function () { dlgForm.querySelector('[name="price"]').setCustomValidity(''); });
        });
        dlgForm.addEventListener('submit', function (e) {
            if (!partyId.value) {
                e.preventDefault();
                lookup.setCustomValidity('Pick a customer from the list.');
                lookup.reportValidity();
                return;
            }
            var p = dlgForm.querySelector('[name="price"]'), d = dlgForm.querySelector('[name="discountPercent"]');
            if (!p.value.trim() && !d.value.trim()) {
                e.preventDefault();
                p.setCustomValidity('Enter an agreed price or a discount.');
                p.reportValidity();
                return;
            }
            p.setCustomValidity('');
        });
    }

    syncType();
    syncPureAgent();
    updatePrice();
})();
