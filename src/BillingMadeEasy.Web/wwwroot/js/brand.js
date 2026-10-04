// Brand kit page: swatches and font previews, the edit toggle, colour rows,
// "Suggest from logo", and drag-and-drop logo upload.
(function () {
    'use strict';
    var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

    // Styles set through the DOM, which the CSP allows (inline style attributes it does not).
    $$('[data-bg]').forEach(function (el) { el.style.backgroundColor = el.getAttribute('data-bg'); el.style.color = el.getAttribute('data-fg'); });
    $$('[data-font]').forEach(function (el) { el.style.fontFamily = '"' + el.getAttribute('data-font') + '", var(--font)'; });

    // Edit toggle (E).
    $$('[data-show]').forEach(function (a) {
        a.addEventListener('click', function (e) {
            e.preventDefault();
            var show = document.querySelector(a.getAttribute('data-show'));
            var hide = document.querySelector(a.getAttribute('data-hide'));
            if (show) show.hidden = false;
            if (hide) hide.hidden = true;
            a.hidden = true;
            var first = show && show.querySelector('input:not([type=hidden]):not([type=color]), textarea');
            if (first) first.focus();
        });
    });

    // ── Colour rows ──
    var rows = document.querySelector('[data-color-rows]');
    function normalize(hex) {
        var m = String(hex || '').trim().match(/^#?([0-9a-f]{6}|[0-9a-f]{3})$/i);
        if (!m) return null;
        var h = m[1].toUpperCase();
        if (h.length === 3) h = h.split('').map(function (c) { return c + c; }).join('');
        return '#' + h;
    }
    function renumber() {
        $$('[data-color-row]', rows).forEach(function (row, i) {
            $$('input[name]', row).forEach(function (input) {
                input.name = input.name.replace(/Colors\[\d+\]/, 'Colors[' + i + ']');
            });
        });
    }
    function wire(row) {
        var picker = row.querySelector('[data-color-picker]');
        var hex = row.querySelector('[data-color-hex]');
        picker.addEventListener('input', function () { hex.value = picker.value.toUpperCase(); hex.dispatchEvent(new Event('input', { bubbles: true })); });
        hex.addEventListener('input', function () { var n = normalize(hex.value); if (n) picker.value = n.toLowerCase(); });
        row.querySelector('[data-remove-color]').addEventListener('click', function () {
            if ($$('[data-color-row]', rows).length > 1) row.remove();
            else { hex.value = ''; row.querySelector('input[name$=".Name"]').value = ''; }
            renumber();
            rows.closest('form').dispatchEvent(new Event('change', { bubbles: true }));
        });
    }
    function addRow(hexValue, name) {
        var empty = $$('[data-color-row]', rows).filter(function (r) { return !r.querySelector('[data-color-hex]').value; })[0];
        var row = empty || rows.lastElementChild.cloneNode(true);
        if (!empty) {
            $$('input[type=text]', row).forEach(function (i) { i.value = ''; });
            $$('.field-error', row).forEach(function (e) { e.textContent = ''; });
            rows.appendChild(row);
            wire(row);
            renumber();
        }
        if (hexValue) {
            row.querySelector('[data-color-hex]').value = hexValue;
            row.querySelector('[data-color-picker]').value = hexValue.toLowerCase();
        }
        if (name) row.querySelector('input[name$=".Name"]').value = name;
        return row;
    }
    if (rows) {
        $$('[data-color-row]', rows).forEach(wire);
        var add = document.querySelector('[data-add-color]');
        if (add) add.addEventListener('click', function () { addRow().querySelector('[data-color-hex]').focus(); });
    }

    // ── Suggest from logo: the most common distinct colours, ignoring transparency, near-white and near-black ──
    var suggest = document.querySelector('[data-suggest-colors]');
    if (suggest) {
        suggest.addEventListener('click', function () {
            var img = new Image();
            img.onload = function () {
                var size = 96, canvas = document.createElement('canvas');
                var scale = Math.min(1, size / Math.max(img.naturalWidth || size, img.naturalHeight || size));
                canvas.width = Math.max(1, Math.round((img.naturalWidth || size) * scale));
                canvas.height = Math.max(1, Math.round((img.naturalHeight || size) * scale));
                var ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                var data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
                var buckets = {};
                for (var i = 0; i < data.length; i += 4) {
                    if (data[i + 3] < 200) continue;
                    var r = data[i], g = data[i + 1], b = data[i + 2];
                    var max = Math.max(r, g, b), min = Math.min(r, g, b);
                    if (max > 245 && min > 245) continue;      // background white
                    if (max < 12) continue;                    // background black
                    var key = (r >> 4) + ',' + (g >> 4) + ',' + (b >> 4);
                    var bk = buckets[key] || (buckets[key] = { n: 0, r: 0, g: 0, b: 0 });
                    bk.n++; bk.r += r; bk.g += g; bk.b += b;
                }
                var picked = [];
                Object.keys(buckets).map(function (k) { return buckets[k]; })
                    .sort(function (a, b) { return b.n - a.n; })
                    .forEach(function (bk) {
                        var c = [Math.round(bk.r / bk.n), Math.round(bk.g / bk.n), Math.round(bk.b / bk.n)];
                        var distinct = picked.every(function (p) {
                            return Math.abs(p[0] - c[0]) + Math.abs(p[1] - c[1]) + Math.abs(p[2] - c[2]) > 90;
                        });
                        if (distinct && picked.length < 5) picked.push(c);
                    });
                if (!picked.length) { alert('No clear colours found in this logo.'); return; }
                var names = ['Primary', 'Secondary', 'Accent', 'Accent 2', 'Accent 3'];
                picked.forEach(function (c, i) {
                    var hex = '#' + c.map(function (v) { return ('0' + v.toString(16)).slice(-2); }).join('').toUpperCase();
                    var exists = $$('[data-color-hex]', rows).some(function (h) { return normalize(h.value) === hex; });
                    if (!exists) addRow(hex, names[i]);
                });
                rows.closest('form').dispatchEvent(new Event('change', { bubbles: true }));
            };
            img.onerror = function () { alert("The logo couldn't be read."); };
            img.src = suggest.getAttribute('data-suggest-colors');
        });
    }

    // ── Logo upload: choosing a file, or dropping one on its tile, uploads it ──
    $$('form[data-upload]').forEach(function (form) {
        var input = form.querySelector('input[type=file]');
        input.addEventListener('change', function () { if (input.files.length) form.submit(); });
        var tile = form.closest('.logo-tile');
        ['dragenter', 'dragover'].forEach(function (t) {
            tile.addEventListener(t, function (e) { e.preventDefault(); tile.classList.add('drop'); });
        });
        ['dragleave', 'drop'].forEach(function (t) {
            tile.addEventListener(t, function () { tile.classList.remove('drop'); });
        });
        tile.addEventListener('drop', function (e) {
            e.preventDefault();
            if (!e.dataTransfer.files.length) return;
            input.files = e.dataTransfer.files;
            form.submit();
        });
    });
})();
