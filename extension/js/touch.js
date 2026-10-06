/* Touch gestures for Guacamole 1.6 (guacamole-plasma-wayland).
 * Guacamole disables pinch-to-zoom in touchpad mode (clientPinch returns if !emulateAbsoluteMouse); this
 * re-implements it with the same formula, makes the zoomed view follow the pointer and adds two buttons. */
(function () {
    if (!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches)) return;
    var inClient = function () { return /^#\/client\//.test(location.hash); };
    function scope() {
        var el = document.querySelector('.client-main');
        var sc = el && window.angular && window.angular.element(el).scope();
        return sc && sc.client && sc.client.clientProperties ? sc : null;
    }
    function two(ev) {
        var a = ev.touches[0], b = ev.touches[1];
        return { d: Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY),
                 x: (a.clientX + b.clientX) / 2, y: (a.clientY + b.clientY) / 2 };
    }
    var g = null;
    document.addEventListener('touchstart', function (ev) {
        var sc = inClient() && ev.touches.length === 2 && scope();
        if (!sc || sc.emulateAbsoluteMouse) { g = null; return; }   // touchscreen mode: native pinch
        var t = two(ev), cp = sc.client.clientProperties;
        g = { sc: sc, d0: t.d, x0: t.x, y0: t.y, mode: null, scale: cp.scale,
              px: (t.x + cp.scrollLeft) / cp.scale, py: (t.y + cp.scrollTop) / cp.scale };
    }, { capture: true, passive: true });
    document.addEventListener('touchmove', function (ev) {
        if (!g || ev.touches.length !== 2) return;
        var t = two(ev), dd = Math.abs(t.d - g.d0), dc = Math.hypot(t.x - g.x0, t.y - g.y0);
        if (!g.mode) {
            if (dd > 14 && dd > dc) g.mode = 'pinch';
            else if (dc > 14) g.mode = 'other';            // parallel fingers: Guacamole scroll wheel
            else return;
        }
        if (g.mode !== 'pinch') return;
        ev.preventDefault();
        ev.stopImmediatePropagation();
        var cp = g.sc.client.clientProperties;
        var s = Math.min(Math.max(g.scale * t.d / g.d0, cp.minScale), cp.maxScale);
        g.sc.$apply(function () {
            cp.autoFit = false;
            cp.scale = s;
            cp.scrollLeft = g.px * s - t.x;
            cp.scrollTop = g.py * s - t.y;
        });
    }, { capture: true, passive: false });
    document.addEventListener('touchend', function (ev) { if (ev.touches.length < 2) g = null; }, true);

    // Zoomed in touchpad mode the finger moves the pointer, not the image: keep the pointer visible
    setInterval(function () {
        var sc = inClient() && scope();
        if (!sc || sc.emulateAbsoluteMouse) return;
        var cp = sc.client.clientProperties, main = document.querySelector('.client-main .main');
        var disp = sc.client.client && sc.client.client.getDisplay && sc.client.client.getDisplay();
        if (!main || !disp || cp.autoFit || cp.scale <= cp.minScale + 0.001) return;
        var x = disp.cursorX * cp.scale, y = disp.cursorY * cp.scale, m = 40;
        var sl = cp.scrollLeft, st = cp.scrollTop, w = main.clientWidth, h = main.clientHeight;
        if (x - sl < m) sl = x - m; else if (x - sl > w - m) sl = x - w + m;
        if (y - st < m) st = y - m; else if (y - st > h - m) st = y - h + m;
        if (sl !== cp.scrollLeft || st !== cp.scrollTop) {
            sc.$applyAsync(function () { cp.scrollLeft = Math.max(0, sl); cp.scrollTop = Math.max(0, st); });
        }
    }, 120);

    // Floating buttons: menu (the left-edge swipe collides with the Android back gesture) and fit-to-screen
    function button(id, label, text, action) {
        var b = document.createElement('button');
        b.id = id;
        b.type = 'button';
        b.setAttribute('aria-label', label);
        b.textContent = text;
        b.addEventListener('click', function (ev) { ev.preventDefault(); ev.stopPropagation(); action(); });
        return b;
    }
    var menu = button('gp-menu-button', 'Menu', '☰', function () {
        var inj = window.angular && window.angular.element(document.body).injector();
        if (inj) { var root = inj.get('$rootScope'); root.$apply(function () { root.$broadcast('guacToggleMenu'); }); }
    });
    var fit = button('gp-fit-button', 'Fit to screen', '⤢', function () {
        var sc = scope();
        if (sc) sc.$apply(function () { sc.client.clientProperties.autoFit = true; });
    });
    function place() {
        var sc = inClient() && scope();
        menu.style.display = inClient() ? 'block' : 'none';
        fit.style.display = sc && !sc.client.clientProperties.autoFit ? 'block' : 'none';
    }
    document.addEventListener('DOMContentLoaded', function () {
        document.body.appendChild(menu);
        document.body.appendChild(fit);
        place();
    });
    setInterval(place, 500);
})();
