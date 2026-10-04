// Role editor: type to filter permissions, tick a whole group at once (tri-state), live count.
(function () {
    'use strict';
    var filter = document.querySelector('[data-perm-filter]');
    var count = document.querySelector('[data-perm-count]');
    var groups = Array.prototype.slice.call(document.querySelectorAll('[data-perm-group]'));

    function boxes(group) { return Array.prototype.slice.call(group.querySelectorAll('[data-perm] input[type="checkbox"]')); }

    function syncGroup(group) {
        var all = group.querySelector('[data-perm-all]');
        var usable = boxes(group).filter(function (b) { return !b.disabled; });
        var on = usable.filter(function (b) { return b.checked; }).length;
        all.checked = usable.length > 0 && on === usable.length;
        all.indeterminate = on > 0 && on < usable.length;
        all.disabled = usable.length === 0;
    }
    function syncCount() {
        if (count) count.textContent = document.querySelectorAll('[data-perm] input:checked').length;
    }

    groups.forEach(function (group) {
        var all = group.querySelector('[data-perm-all]');
        all.addEventListener('change', function () {
            boxes(group).forEach(function (b) { if (!b.disabled) b.checked = all.checked; });
            syncGroup(group); syncCount();
            group.closest('form').dispatchEvent(new Event('change', { bubbles: true }));
        });
        group.addEventListener('change', function (e) {
            if (e.target.matches('[data-perm] input')) { syncGroup(group); syncCount(); }
        });
        syncGroup(group);
    });

    if (filter) {
        filter.addEventListener('input', function () {
            var q = filter.value.trim().toLowerCase();
            document.querySelectorAll('[data-perm]').forEach(function (el) {
                el.hidden = q !== '' && el.getAttribute('data-search').indexOf(q) === -1;
            });
            groups.forEach(function (g) { g.hidden = boxes(g).every(function (b) { return b.closest('[data-perm]').hidden; }); });
            document.querySelectorAll('[data-perm-module]').forEach(function (m) {
                m.hidden = Array.prototype.every.call(m.querySelectorAll('[data-perm-group]'), function (g) { return g.hidden; });
            });
        });
        filter.addEventListener('keydown', function (e) { if (e.key === 'Enter') e.preventDefault(); });
    }
})();
