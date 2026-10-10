// Your business: a live preview of the invoice heading, the accent colour, IFSC checks, and a
// numbering-series preview that shows the exact number the next document will get.
(function () {
    'use strict';
    var $ = function (sel, root) { return (root || document).querySelector(sel); };
    var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

    // Profile cards on the list take their accent colour.
    $$('[data-accent]').forEach(function (el) {
        var c = el.getAttribute('data-accent');
        if (/^#[0-9A-Fa-f]{6}$/.test(c)) el.style.setProperty('--profile-accent', c);
    });

    // ── Invoice heading preview ──
    var form = $('[data-profile-form]');
    var preview = $('[data-invoice-preview]');
    if (form && preview) {
        var val = function (key) { var el = $('[data-preview="' + key + '"]', form); return el ? el.value.trim() : ''; };
        var stateName = function () {
            var s = $('[data-preview="state"]', form);
            if (!s || !s.value) return '';
            return s.options[s.selectedIndex].text.replace(/\s*\(\d+\)$/, '');
        };
        var put = function (key, text) { var el = $('[data-ip="' + key + '"]', preview); if (el) { el.textContent = text; el.hidden = !text; } };
        var composition = $('[name="Form.IsComposition"][type="checkbox"]', form);
        var update = function () {
            var name = val('name'), legal = val('legal');
            put('name', name || 'Your business name');
            put('legal', legal && legal !== name ? legal : '');
            var place = [val('city'), val('pin')].filter(Boolean).join(' ');
            put('address', [val('line1'), val('line2'), [place, stateName()].filter(Boolean).join(', ')].filter(Boolean).join(', '));
            put('contact', [val('phone'), val('email')].filter(Boolean).join(' · '));
            put('gstin', val('gstin') ? 'GSTIN ' + val('gstin').toUpperCase() : '');
            put('doc', composition && composition.checked ? 'BILL OF SUPPLY' : 'TAX INVOICE');
            var accent = val('accent');
            preview.style.setProperty('--ip-accent', /^#[0-9A-Fa-f]{6}$/.test(accent) ? accent : '');
        };
        form.addEventListener('input', update);
        form.addEventListener('change', update);
        update();

        // Accent picker ↔ code.
        var picker = $('[data-color-picker]', form), hex = $('[data-color-hex]', form);
        if (picker && hex) {
            picker.addEventListener('input', function () { hex.value = picker.value.toUpperCase(); update(); });
            hex.addEventListener('input', function () { if (/^#[0-9A-Fa-f]{6}$/.test(hex.value)) picker.value = hex.value.toLowerCase(); });
        }
    }

    // ── IFSC: format check and the bank it belongs to ──
    var banks = { SBIN: 'State Bank of India', HDFC: 'HDFC Bank', ICIC: 'ICICI Bank', UTIB: 'Axis Bank', KKBK: 'Kotak Mahindra Bank',
        BARB: 'Bank of Baroda', PUNB: 'Punjab National Bank', CNRB: 'Canara Bank', UBIN: 'Union Bank of India', INDB: 'IndusInd Bank',
        YESB: 'Yes Bank', IDFB: 'IDFC FIRST Bank', BKID: 'Bank of India', IDIB: 'Indian Bank', FDRL: 'Federal Bank', RATN: 'RBL Bank',
        AUBL: 'AU Small Finance Bank', SRCB: 'Saraswat Co-operative Bank', MAHB: 'Bank of Maharashtra', IOBA: 'Indian Overseas Bank',
        UCBA: 'UCO Bank', CBIN: 'Central Bank of India', PSIB: 'Punjab & Sind Bank', IBKL: 'IDBI Bank', KARB: 'Karnataka Bank',
        SIBL: 'South Indian Bank', CIUB: 'City Union Bank', TMBL: 'Tamilnad Mercantile Bank', DCBL: 'DCB Bank', BDBL: 'Bandhan Bank',
        ESFB: 'Equitas Small Finance Bank', USFB: 'Ujjivan Small Finance Bank', JAKA: 'Jammu & Kashmir Bank', KVBL: 'Karur Vysya Bank' };
    $$('[data-ifsc]').forEach(function (input) {
        var help = input.parentElement.querySelector('[data-ifsc-help]');
        var original = help ? help.textContent : '';
        var bankField = input.form.querySelector('[name="Bank.BankName"]');
        input.addEventListener('input', function () {
            input.value = input.value.toUpperCase().replace(/\s/g, '');
            var v = input.value;
            if (!help) return;
            if (!v) { help.className = 'field-help'; help.textContent = original; return; }
            if (v.length < 11) { help.className = 'field-help'; help.textContent = (11 - v.length) + ' more to go'; return; }
            if (!/^[A-Z]{4}0[A-Z0-9]{6}$/.test(v)) { help.className = 'field-help bad'; help.textContent = 'An IFSC is 4 letters, a zero, then 6 letters or digits.'; return; }
            var bank = banks[v.slice(0, 4)];
            help.className = 'field-help ok';
            help.textContent = bank ? '✓ ' + bank : '✓ Looks right';
            if (bank && bankField && !bankField.value) bankField.value = bank;
        });
    });

    // ── Numbering preview ── mirrors dbo.fn_FormatDocNumber
    var seriesForm = $('[data-series-form]');
    if (seriesForm) {
        var year = parseInt(seriesForm.getAttribute('data-year'), 10);
        var out = $('[data-series-preview]', seriesForm);
        var locked = $('[data-series-locked]', seriesForm);
        var field = function (n) { return seriesForm.querySelector('[name="SeriesForm.' + n + '"]:not([type="hidden"])') || seriesForm.querySelector('[name="SeriesForm.' + n + '"]'); };
        var two = function (n) { return ('0' + (n % 100)).slice(-2); };
        var format = function (prefix, suffix, sep, yf, seq, pad) {
            var y = yf === 1 ? year + '-' + two(year + 1) : yf === 2 ? two(year) + '-' + two(year + 1) : yf === 3 ? String(year) : null;
            var digits = String(seq);
            while (digits.length < pad) digits = '0' + digits;
            var r = prefix || '';
            if (y !== null) r = r ? r + sep + y : y;
            r = r ? r + sep + digits : digits;
            if (suffix) r += sep + suffix;
            return r;
        };
        var render = function () {
            var prefix = field('Prefix').value.trim().toUpperCase();
            var suffix = field('Suffix').value.trim().toUpperCase();
            var sep = field('Separator').value;
            var yf = parseInt(field('YearFormat').value, 10) || 0;
            var pad = Math.min(10, Math.max(1, parseInt(field('PadWidth').value, 10) || 1));
            var issued = parseInt($('[data-issued]', seriesForm).value, 10) || 0;
            var next = issued > 0 ? (parseInt($('[data-next-seq]', seriesForm).value, 10) || 1) : (parseInt(field('StartFrom').value, 10) || 1);
            var first = format(prefix, suffix, sep, yf, next, pad);
            var longest = format(prefix, suffix, sep, yf, Math.max(next, Math.pow(10, pad) - 1), pad);
            out.textContent = '';
            var line = document.createElement('span');
            line.className = 'mono strong';
            line.textContent = first + ', ' + format(prefix, suffix, sep, yf, next + 1, pad) + ' …';
            var note = document.createElement('span');
            note.className = 'sub' + (longest.length > 16 ? ' bad' : '');
            note.textContent = longest.length > 16
                ? 'Too long: GST allows 16 characters and this reaches ' + longest.length + '. Shorten the prefix or use fewer digits.'
                : longest.length + ' of 16 characters at most' + (yf === 0 && field('ResetYearly').checked ? ' · without the year, numbers repeat each April — keep the year in' : '');
            if (yf === 0 && field('ResetYearly').checked) note.className = 'sub bad';
            out.appendChild(line); out.appendChild(note);
            var bad = /[^A-Z0-9/-]/.test(prefix + suffix);
            if (bad) { note.className = 'sub bad'; note.textContent = 'Prefix and suffix can hold letters, numbers, / and - only.'; }
        };
        var lock = function () {
            var isLocked = (parseInt($('[data-issued]', seriesForm).value, 10) || 0) > 0;
            locked.hidden = !isLocked;
            $$('[data-format]', seriesForm).forEach(function (el) { el.disabled = isLocked; });
            field('DocumentType').disabled = isLocked;
            render();
        };
        seriesForm.addEventListener('input', render);
        seriesForm.addEventListener('change', render);
        // After dialogs.js fills the form from the row, lock or unlock the format fields.
        document.addEventListener('click', function (e) {
            if (e.target.closest && e.target.closest('[data-dialog="series"]')) setTimeout(lock, 0);
        });
        // Disabled fields don't post; re-enable just before submit so the server sees the stored format.
        seriesForm.addEventListener('submit', function () { $$('[data-format], select', seriesForm).forEach(function (el) { el.disabled = false; }); });
        lock();
    }
})();
