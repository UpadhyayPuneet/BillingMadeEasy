// In-place editing with <dialog>: buttons with data-dialog="kind" open #dlg-kind, filled from
// data-item JSON when editing, empty when adding. Ctrl+Enter saves, Esc closes (native).
// A dialog the server re-rendered after a failed save (data-open) reopens with its errors.
(function () {
    'use strict';

    function prefixOf(form) {
        var hidden = form.querySelector('input[type="hidden"][name*="."]');
        return hidden ? hidden.name.split('.')[0] + '.' : '';
    }

    function fill(dialog, item) {
        var form = dialog.querySelector('form');
        var prefix = prefixOf(form);
        form.reset();
        form.querySelectorAll('input:not([type="hidden"][name="__RequestVerificationToken"]), select, textarea').forEach(function (el) {
            if (!el.name || el.name.indexOf(prefix) !== 0) return;
            var key = el.name.slice(prefix.length);
            var value = item && Object.prototype.hasOwnProperty.call(item, key) ? item[key] : null;
            if (el.type === 'checkbox') el.checked = value === true;
            else if (el.type === 'hidden' && el.value === 'false') return;      // checkbox companion
            else el.value = value === null || value === undefined ? (el.type === 'hidden' ? '0' : '') : String(value);
        });
        form.querySelectorAll('.field-error, [data-gstin-result]').forEach(function (el) { el.textContent = ''; });
        var summary = form.querySelector('.validation-summary-errors');
        if (summary) summary.innerHTML = '';
        var title = dialog.querySelector('[data-new-title]');
        if (title) title.textContent = title.getAttribute(item ? 'data-edit-title' : 'data-new-title');
    }

    function open(dialog, item, keepValues) {
        if (!keepValues) fill(dialog, item);
        dialog.showModal();
        var first = dialog.querySelector('input:not([type="hidden"]), select, textarea');
        if (first) first.focus();
    }

    document.addEventListener('click', function (e) {
        var trigger = e.target.closest && e.target.closest('[data-dialog]');
        if (trigger) {
            var dialog = document.getElementById('dlg-' + trigger.getAttribute('data-dialog'));
            if (!dialog) return;
            var raw = trigger.getAttribute('data-item');
            open(dialog, raw ? JSON.parse(raw) : null, false);
            return;
        }
        var close = e.target.closest && e.target.closest('[data-close]');
        if (close) { var d = close.closest('dialog'); if (d) d.close(); }
    });

    // Click on the backdrop closes.
    document.querySelectorAll('dialog').forEach(function (dialog) {
        dialog.addEventListener('mousedown', function (e) { if (e.target === dialog) dialog.close(); });
        dialog.addEventListener('keydown', function (e) {
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                e.preventDefault();
                dialog.querySelector('form').requestSubmit();
            }
            e.stopPropagation();   // keys typed in a dialog never trigger page shortcuts
        });
        if (dialog.getAttribute('data-open') === 'true') {
            var title = dialog.querySelector('[data-new-title]');
            var idField = dialog.querySelector('input[type="hidden"][name$="Id"]');
            if (title && idField && idField.value && idField.value !== '0') title.textContent = title.getAttribute('data-edit-title');
            open(dialog, null, true);
        }
    });

    // Buttons that need a confirmation of their own (several actions share one form).
    document.addEventListener('click', function (e) {
        var b = e.target.closest && e.target.closest('[data-confirm-click]');
        if (b && !confirm(b.getAttribute('data-confirm-click'))) { e.preventDefault(); e.stopPropagation(); }
    }, true);

    // Copy to clipboard with feedback.
    document.addEventListener('click', function (e) {
        var b = e.target.closest && e.target.closest('[data-copy]');
        if (!b) return;
        var text = b.getAttribute('data-copy');
        var done = function () {
            var label = b.lastChild; var old = label.textContent;
            label.textContent = 'Copied';
            setTimeout(function () { label.textContent = old; }, 1600);
        };
        if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text).then(done);
        else {
            var field = b.parentElement.querySelector('input[readonly]');
            if (field) { field.select(); document.execCommand('copy'); done(); }
        }
    });
    document.querySelectorAll('[data-select-all]').forEach(function (el) {
        el.addEventListener('focus', function () { el.select(); });
    });

    // Confirm before destructive posts.
    document.addEventListener('submit', function (e) {
        var message = e.target.getAttribute && e.target.getAttribute('data-confirm');
        if (message && !confirm(message)) e.preventDefault();
    }, true);
})();
