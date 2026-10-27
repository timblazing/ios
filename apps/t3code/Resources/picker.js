(function (root) {
    'use strict';
    var ids = ['project-filter', 'new-project', 'provider', 'model'];
    var names = {'project-filter': 'Filter project', 'new-project': 'Project', provider: 'Provider', model: 'Model'};
    var doc = root.document, entries = [], opened = null, menu = null, activeValue = null, menuSignature = '';

    function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
    function place(anchor, viewport, preferredWidth, rows) {
        var margin = 8, gap = 6, width = Math.min(Math.max(anchor.width, preferredWidth), Math.max(0, viewport.width - margin * 2));
        var desired = Math.min(rows * 44 + 12, 332), below = Math.max(0, viewport.height - margin - anchor.bottom - gap), above = Math.max(0, anchor.top - margin - gap);
        var useAbove = below < Math.min(desired, 176) && above > below;
        var height = Math.min(desired, useAbove ? above : below);
        return {
            left: clamp(anchor.left, margin, Math.max(margin, viewport.width - width - margin)),
            top: useAbove ? Math.max(margin, anchor.top - gap - height) : Math.min(viewport.height - margin, anchor.bottom + gap),
            width: width,
            maxHeight: Math.max(0, height)
        };
    }
    function optionsOf(select) {
        var result = [];
        for (var i = 0; i < select.options.length; i++) {
            var option = select.options[i];
            result.push({value: option.value, label: option.textContent || option.label || option.value, disabled: !!option.disabled || !!(option.parentNode && option.parentNode.disabled)});
        }
        return result;
    }
    function signature(options) { return JSON.stringify(options); }
    function contains(parent, target) { return !!parent && (parent === target || parent.contains(target)); }
    function selectedOption(entry) {
        var index = entry.select.selectedIndex;
        return index >= 0 && index < entry.select.options.length ? entry.select.options[index] : null;
    }
    function enabled(options, value) {
        for (var i = 0; i < options.length; i++) if (options[i].value === value && !options[i].disabled) return true;
        return false;
    }
    function firstEnabled(options) {
        for (var i = 0; i < options.length; i++) if (!options[i].disabled) return options[i].value;
        return null;
    }
    function viewport() {
        var visual = root.visualViewport;
        return {width: visual ? visual.width : root.innerWidth, height: visual ? visual.height : root.innerHeight};
    }
    function position() {
        if (!opened || !menu) return;
        var rect = opened.trigger.getBoundingClientRect(), size = viewport();
        if (rect.width === 0 || rect.height === 0 || rect.bottom <= 0 || rect.top >= size.height) { close(false); return; }
        var bounds = place(rect, size, opened.select.id === 'model' ? 300 : 260, opened.options.length);
        if (bounds.maxHeight < 44) { close(false); return; }
        menu.style.left = bounds.left + 'px';
        menu.style.top = bounds.top + 'px';
        menu.style.width = bounds.width + 'px';
        menu.style.maxHeight = bounds.maxHeight + 'px';
    }
    function close(restoreFocus) {
        var previous = opened;
        if (previous) previous.trigger.setAttribute('aria-expanded', 'false');
        if (menu && menu.parentNode) menu.parentNode.removeChild(menu);
        menu = null; opened = null; activeValue = null; menuSignature = '';
        if (restoreFocus && previous && !previous.trigger.disabled) previous.trigger.focus();
    }
    function updateActive(reveal) {
        if (!menu || !opened) return;
        var buttons = menu.children, current = null;
        for (var i = 0; i < buttons.length; i++) {
            var button = buttons[i], active = button.getAttribute('data-value') === activeValue;
            button.className = 'picker-option' + (active ? ' picker-active' : '');
            button.setAttribute('aria-selected', button.getAttribute('data-value') === opened.select.value ? 'true' : 'false');
            if (active) current = button;
        }
        if (current) {
            menu.setAttribute('aria-activedescendant', current.id);
            if (reveal) {
                var top = current.offsetTop, bottom = top + current.offsetHeight;
                if (top < menu.scrollTop) menu.scrollTop = top;
                else if (bottom > menu.scrollTop + menu.clientHeight) menu.scrollTop = bottom - menu.clientHeight;
            }
        } else menu.removeAttribute('aria-activedescendant');
    }
    function choose(value) {
        if (!opened || opened.select.disabled || !enabled(opened.options, value)) return;
        var entry = opened, changed = entry.select.value !== value;
        entry.select.value = value;
        close(true);
        sync();
        if (changed) {
            // One dispatch invokes both property handlers and registered listeners exactly once.
            var event = doc.createEvent('Event');
            event.initEvent('change', true, false);
            entry.select.dispatchEvent(event);
            sync();
        }
    }
    function drawMenu() {
        if (!opened || !menu) return;
        var nextSignature = signature(opened.options);
        if (nextSignature !== menuSignature) {
            var oldScroll = menu.scrollTop;
            menu.textContent = '';
            for (var i = 0; i < opened.options.length; i++) {
                var option = opened.options[i], button = doc.createElement('button');
                button.type = 'button';
                button.id = opened.select.id + '-choice-' + i;
                button.tabIndex = -1;
                button.className = 'picker-option';
                button.setAttribute('role', 'option');
                button.setAttribute('data-value', option.value);
                button.setAttribute('aria-disabled', option.disabled ? 'true' : 'false');
                button.disabled = option.disabled;
                button.textContent = option.label;
                button.onclick = function (event) { event.preventDefault(); choose(this.getAttribute('data-value')); };
                menu.appendChild(button);
            }
            menu.scrollTop = oldScroll;
            menuSignature = nextSignature;
        }
        if (!enabled(opened.options, activeValue)) activeValue = enabled(opened.options, opened.select.value) ? opened.select.value : firstEnabled(opened.options);
        updateActive(false);
        position();
    }
    function move(direction) {
        if (!opened) return;
        var options = opened.options, index = -1;
        for (var i = 0; i < options.length; i++) if (options[i].value === activeValue) index = i;
        for (var step = 1; step <= options.length; step++) {
            var candidate = (index + direction * step + options.length) % options.length;
            if (!options[candidate].disabled) { activeValue = options[candidate].value; updateActive(true); return; }
        }
    }
    function onKey(event) {
        if (!opened) return;
        if (event.keyCode === 27) { event.preventDefault(); close(true); }
        else if (event.keyCode === 38 || event.keyCode === 40) { event.preventDefault(); move(event.keyCode === 38 ? -1 : 1); }
        else if (event.keyCode === 13 || event.keyCode === 32) { event.preventDefault(); choose(activeValue); }
        else if (event.keyCode === 36 || event.keyCode === 35) {
            event.preventDefault();
            var options = opened.options;
            for (var i = event.keyCode === 36 ? 0 : options.length - 1; i >= 0 && i < options.length; i += event.keyCode === 36 ? 1 : -1) {
                if (!options[i].disabled) { activeValue = options[i].value; updateActive(true); break; }
            }
        } else if (event.keyCode === 9) close(true);
    }
    function open(entry) {
        if (entry.trigger.disabled) return;
        if (opened === entry) { close(false); return; }
        close(false);
        opened = entry;
        activeValue = enabled(entry.options, entry.select.value) ? entry.select.value : firstEnabled(entry.options);
        menu = doc.createElement('div');
        menu.id = 't3-picker-menu';
        menu.className = 'picker-menu';
        menu.tabIndex = -1;
        menu.setAttribute('role', 'listbox');
        menu.setAttribute('aria-label', names[entry.select.id]);
        menu.onkeydown = onKey;
        doc.body.appendChild(menu);
        entry.trigger.setAttribute('aria-expanded', 'true');
        drawMenu();
        if (menu) { menu.focus(); updateActive(true); }
    }
    function sync() {
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i], selected = selectedOption(entry), label = selected ? selected.textContent || selected.label || selected.value : 'Choose ' + names[entry.select.id].toLowerCase();
            entry.options = optionsOf(entry.select);
            if (entry.label.textContent !== label) entry.label.textContent = label;
            entry.trigger.disabled = entry.select.disabled || firstEnabled(entry.options) === null;
            entry.trigger.setAttribute('aria-label', names[entry.select.id] + ': ' + label);
            entry.trigger.title = label;
        }
        if (opened) {
            if (opened.trigger.disabled) close(false);
            else drawMenu();
        }
    }
    function init() {
        if (!doc) return;
        for (var i = 0; i < ids.length; i++) {
            var select = doc.getElementById(ids[i]);
            if (!select || select.getAttribute('data-custom-picker') === 'true') continue;
            var trigger = doc.createElement('button'), label = doc.createElement('span'), chevron = doc.createElement('span');
            select.setAttribute('data-custom-picker', 'true');
            select.setAttribute('aria-hidden', 'true');
            select.setAttribute('tabindex', '-1');
            select.style.display = 'none';
            trigger.id = ids[i] + '-picker';
            trigger.type = 'button';
            trigger.className = 'picker-trigger';
            trigger.setAttribute('aria-haspopup', 'listbox');
            trigger.setAttribute('aria-expanded', 'false');
            trigger.setAttribute('aria-controls', 't3-picker-menu');
            label.className = 'picker-label';
            chevron.className = 'picker-chevron';
            chevron.setAttribute('aria-hidden', 'true');
            // iOS 10 WebKit ignores flex layout on <button>, so the flex row lives on an inner span.
            var inner = doc.createElement('span');
            inner.className = 'picker-inner';
            inner.appendChild(label); inner.appendChild(chevron); trigger.appendChild(inner);
            select.parentNode.insertBefore(trigger, select.nextSibling);
            var entry = {select: select, trigger: trigger, label: label, options: []};
            entries.push(entry);
            (function (item) {
                item.trigger.onclick = function (event) { event.preventDefault(); open(item); };
                item.trigger.onkeydown = function (event) {
                    if (event.keyCode === 38 || event.keyCode === 40) { event.preventDefault(); if (opened !== item) open(item); else move(event.keyCode === 38 ? -1 : 1); }
                };
                item.select.addEventListener('change', sync);
                if (root.MutationObserver) {
                    var observer = new root.MutationObserver(sync);
                    observer.observe(item.select, {childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ['disabled', 'selected', 'value', 'label']});
                    item.observer = observer;
                }
            })(entry);
        }
        sync();
    }
    var api = {init: init, sync: sync, close: function () { close(false); }};
    root.T3Pickers = api;
    if (typeof module !== 'undefined' && module.exports) module.exports = {place: place};
    if (!doc) return;
    function outside(event) { if (opened && !contains(opened.trigger, event.target) && !contains(menu, event.target)) close(false); }
    doc.addEventListener('mousedown', outside, true);
    doc.addEventListener('touchstart', outside, true);
    root.addEventListener('resize', position);
    root.addEventListener('orientationchange', function () { close(false); });
    root.addEventListener('pagehide', function () { close(false); });
    root.addEventListener('scroll', function (event) { if (!contains(menu, event.target)) position(); }, true);
    if (root.visualViewport) { root.visualViewport.addEventListener('resize', position); root.visualViewport.addEventListener('scroll', position); }
    if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', init);
    else init();
})(typeof window === 'undefined' ? global : window);
