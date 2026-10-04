// Keyboard-first shell: command bar (Ctrl+K or /), "g then x" go-to chords, ? for help, voice input.
// The command list comes from the server, filtered to the modules and permissions of this business.
// Ranking learns per business and per user (frecency), so each tenant's bar adapts to how it works.
(function () {
    'use strict';

    var $ = function (sel, root) { return (root || document).querySelector(sel); };
    var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

    function readJson(id, fallback) {
        var el = document.getElementById(id);
        if (!el) return fallback;
        try { return JSON.parse(el.textContent); } catch (e) { return fallback; }
    }

    var scope = readJson('bme-scope', 'anon');
    var storeKey = 'bme.frecency.' + scope;
    var commands = readJson('bme-commands', []).concat([
        { title: 'Switch business', href: '/Account/ChooseBusiness', icon: 'swap_horiz', group: 'Account', keywords: 'tenant company workspace change' },
        { title: 'Switch theme', action: 'theme', icon: 'contrast', group: 'Account', keywords: 'dark light mode' },
        { title: 'Keyboard shortcuts', action: 'help', icon: 'keyboard', group: 'Help', keywords: 'keys hotkeys help' },
        { title: 'Sign out', action: 'signout', icon: 'logout', group: 'Account', keywords: 'logout exit' }
    ]);

    // ── Frecency: how often and how recently this person in this business used a command ──
    function loadUsage() {
        try { return JSON.parse(localStorage.getItem(storeKey) || '{}'); } catch (e) { return {}; }
    }
    function recordUse(cmd) {
        var usage = loadUsage();
        var id = cmd.href || cmd.action;
        var entry = usage[id] || { n: 0, t: 0 };
        entry.n += 1; entry.t = Date.now();
        usage[id] = entry;
        try { localStorage.setItem(storeKey, JSON.stringify(usage)); } catch (e) { /* ignore */ }
    }
    function frecency(cmd, usage) {
        var entry = usage[cmd.href || cmd.action];
        if (!entry) return 0;
        var days = (Date.now() - entry.t) / 86400000;
        return entry.n * (days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : 0.5);
    }

    // ── Fuzzy match: every query character in order; bonus for word starts and contiguous runs ──
    function score(query, text) {
        if (!query) return 1;
        text = text.toLowerCase();
        var qi = 0, s = 0, run = 0;
        for (var i = 0; i < text.length && qi < query.length; i++) {
            if (text[i] === query[qi]) {
                run++;
                s += 1 + run + (i === 0 || text[i - 1] === ' ' ? 3 : 0);
                qi++;
            } else {
                run = 0;
            }
        }
        return qi === query.length ? s : 0;
    }

    function search(query) {
        var q = query.trim().toLowerCase().replace(/^(go to|open|show)\s+/, '');
        var usage = loadUsage();
        return commands
            .map(function (c) {
                var m = Math.max(score(q, c.title) * 2, score(q, c.keywords || ''));
                return { cmd: c, rank: m > 0 ? m + frecency(c, usage) * 3 : 0 };
            })
            .filter(function (r) { return r.rank > 0; })
            .sort(function (a, b) { return b.rank - a.rank; })
            .slice(0, 12)
            .map(function (r) { return r.cmd; });
    }

    // ── Command bar ──
    var palette = $('[data-palette]');
    var input = $('[data-palette-input]');
    var list = $('[data-palette-list]');
    var results = [];
    var active = 0;
    var lastFocus = null;

    function render() {
        list.innerHTML = '';
        if (results.length === 0) {
            var empty = document.createElement('li');
            empty.className = 'palette-empty';
            empty.textContent = 'Nothing matches. Try fewer letters.';
            list.appendChild(empty);
            return;
        }
        results.forEach(function (cmd, i) {
            var li = document.createElement('li');
            li.id = 'cmd-' + i;
            li.setAttribute('role', 'option');
            li.className = 'palette-item' + (i === active ? ' active' : '');
            li.setAttribute('aria-selected', i === active ? 'true' : 'false');

            var icon = document.createElement('span');
            icon.className = 'ms'; icon.setAttribute('aria-hidden', 'true'); icon.textContent = cmd.icon || 'chevron_right';
            var title = document.createElement('span');
            title.className = 'palette-title'; title.textContent = cmd.title;
            var group = document.createElement('span');
            group.className = 'palette-group'; group.textContent = cmd.group || '';
            li.append(icon, title, group);
            if (cmd.shortcut) {
                var k = document.createElement('kbd'); k.textContent = 'g ' + cmd.shortcut; li.appendChild(k);
            }
            li.addEventListener('mousemove', function () { if (active !== i) { active = i; render(); } });
            li.addEventListener('click', function () { run(cmd); });
            list.appendChild(li);
        });
        input.setAttribute('aria-activedescendant', 'cmd-' + active);
        var el = document.getElementById('cmd-' + active);
        if (el) el.scrollIntoView({ block: 'nearest' });
    }

    function openPalette(prefill) {
        if (!palette) return;
        lastFocus = document.activeElement;
        palette.hidden = false;
        input.value = prefill || '';
        results = search(input.value); active = 0; render();
        input.focus();
    }
    function closeAll() {
        if (palette) palette.hidden = true;
        var sheet = $('[data-help-sheet]');
        if (sheet) sheet.hidden = true;
        if (lastFocus && lastFocus.focus) lastFocus.focus();
    }

    function run(cmd) {
        recordUse(cmd);
        closeAll();
        if (cmd.href) { window.location.href = cmd.href; return; }
        if (cmd.action === 'theme') toggleTheme();
        if (cmd.action === 'help') showHelp();
        if (cmd.action === 'signout') { var f = $('form[action*="SignOut"]'); if (f) f.submit(); }
    }

    if (input) {
        input.addEventListener('input', function () { results = search(input.value); active = 0; render(); });
        input.addEventListener('keydown', function (e) {
            if (e.key === 'ArrowDown') { e.preventDefault(); active = Math.min(active + 1, results.length - 1); render(); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); active = Math.max(active - 1, 0); render(); }
            else if (e.key === 'Enter') { e.preventDefault(); if (results[active]) run(results[active]); }
            else if (e.key === 'Tab') { e.preventDefault(); }
        });
    }
    if (palette) palette.addEventListener('mousedown', function (e) { if (e.target === palette) closeAll(); });

    // ── Theme and help ──
    function toggleTheme() {
        var root = document.documentElement;
        var current = root.getAttribute('data-theme') ||
            (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
        var next = current === 'dark' ? 'light' : 'dark';
        root.setAttribute('data-theme', next);
        try { localStorage.setItem('bme.theme', next); } catch (e) { /* ignore */ }
    }
    function showHelp() {
        var sheet = $('[data-help-sheet]');
        if (!sheet) return;
        lastFocus = document.activeElement;
        sheet.hidden = false;
        sheet.setAttribute('tabindex', '-1');
        sheet.focus();
    }
    $$('[data-palette-open]').forEach(function (b) { b.addEventListener('click', function () { openPalette(); }); });
    $$('[data-theme-toggle]').forEach(function (b) { b.addEventListener('click', toggleTheme); });
    $$('[data-help]').forEach(function (b) { b.addEventListener('click', showHelp); });
    var helpSheet = $('[data-help-sheet]');
    if (helpSheet) helpSheet.addEventListener('mousedown', function (e) { if (e.target === helpSheet) closeAll(); });

    // ── Voice: speech becomes the command bar query; nothing runs without Enter ──
    var Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    function listen() {
        if (!Recognition) { openPalette(); input.placeholder = 'Voice input needs Chrome or Edge'; return; }
        openPalette();
        var rec = new Recognition();
        rec.lang = document.documentElement.lang || 'en-IN';
        rec.interimResults = true;
        rec.maxAlternatives = 1;
        palette.classList.add('listening');
        rec.onresult = function (e) {
            var text = Array.prototype.map.call(e.results, function (r) { return r[0].transcript; }).join('');
            input.value = text;
            results = search(text); active = 0; render();
        };
        rec.onend = function () { palette.classList.remove('listening'); input.focus(); };
        rec.onerror = rec.onend;
        rec.start();
    }
    $$('[data-voice]').forEach(function (b) { b.addEventListener('click', listen); });

    // ── Global keys ──
    function typing(el) {
        if (!el) return false;
        var tag = el.tagName;
        return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || el.isContentEditable;
    }
    var chord = null, chordTimer = null;

    document.addEventListener('keydown', function (e) {
        var ctrl = e.ctrlKey || e.metaKey;

        if (ctrl && e.shiftKey && e.code === 'Space') { e.preventDefault(); listen(); return; }
        if (ctrl && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); palette && !palette.hidden ? closeAll() : openPalette(); return; }
        if (e.key === 'Escape') { closeAll(); return; }
        if (ctrl || e.altKey || typing(e.target)) return;

        if (chord === 'g') {
            chord = null; clearTimeout(chordTimer);
            var target = commands.filter(function (c) { return c.shortcut === e.key.toLowerCase(); })[0];
            if (target) { e.preventDefault(); run(target); }
            return;
        }
        if (e.key === 'g') { chord = 'g'; chordTimer = setTimeout(function () { chord = null; }, 1200); return; }
        if (e.key === '/') { e.preventDefault(); openPalette(); return; }
        if (e.key === '?') { e.preventDefault(); showHelp(); return; }
    });
})();
