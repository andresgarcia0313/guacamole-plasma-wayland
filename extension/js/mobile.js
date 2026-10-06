/* Mobile improvements for Guacamole 1.6 in Chrome for Android (guacamole-plasma-wayland) */
(function () {
    var touch = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
    var inClient = function () { return /^#\/client\//.test(location.hash); };
    window.gpInClient = inClient;

    // 1. Defaults on touch screens, only when the user has no saved preferences: touchpad mouse (precise
    //    clicks with a finger) and the system keyboard.
    if (touch) {
        try {
            if (!localStorage.getItem('GUAC_PREFERENCES')) {
                localStorage.setItem('GUAC_PREFERENCES', JSON.stringify({ emulateAbsoluteMouse: false, inputMethod: 'text' }));
            }
        } catch (e) { /* storage blocked: Guacamole defaults stay */ }
    }

    // 2. Android keyboard: shrink the layout instead of pushing the canvas up (GUACAMOLE-1953)
    var vp = document.querySelector('meta[name="viewport"]');
    if (vp && touch && vp.content.indexOf('interactive-widget') < 0) {
        vp.content = vp.content.replace(/,?\s*target-densitydpi=[^,]*/, '') + ',interactive-widget=resizes-content';
    }

    // 3. Installable on the home screen (opens without the browser bar)
    if (!document.querySelector('link[rel="manifest"]')) {
        var m = document.createElement('link');
        m.rel = 'manifest';
        m.href = 'app/ext/gplasma/app.webmanifest';
        document.head.appendChild(m);
    }

    // 4. TOTP field: numeric keyboard and one-time-code autofill
    setInterval(function () {
        var f = document.querySelector('input[name="guac-totp"]');
        if (f && f.getAttribute('inputmode') !== 'numeric') {
            f.setAttribute('inputmode', 'numeric');
            f.setAttribute('autocomplete', 'one-time-code');
            f.setAttribute('pattern', '[0-9]*');
            f.setAttribute('maxlength', '6');
        }
    }, 400);

    // 5. Keep the screen on while a remote session is open
    var lock = null;
    function keepAwake() {
        if (!('wakeLock' in navigator)) return;
        if (inClient() && document.visibilityState === 'visible' && !lock) {
            navigator.wakeLock.request('screen').then(function (l) {
                lock = l;
                l.addEventListener('release', function () { lock = null; });
            }).catch(function () { lock = null; });
        } else if (!inClient() && lock) {
            lock.release();
        }
    }
    document.addEventListener('visibilitychange', keepAwake);
    window.addEventListener('hashchange', keepAwake);
    document.addEventListener('click', keepAwake, true);

    // 6. Network recovery (Wi-Fi to mobile data). A dead tunnel shows a fatal error without a button or a
    //    notice with "Reconnect"; Android does not always fire 'online', so it is checked every 5 s.
    var lastTry = 0;
    function recover() {
        if (!navigator.onLine || Date.now() - lastTry < 20000) return;
        var buttons = document.querySelectorAll('.notification button, .client-status-modal button');
        for (var i = 0; i < buttons.length; i++) {
            if (/reconnect|reconect/i.test(buttons[i].textContent)) {
                lastTry = Date.now();
                buttons[i].click();
                return;
            }
        }
        if (!document.querySelector('.fatal-page-error-modal')) return;
        lastTry = Date.now();
        fetch('api/languages', { cache: 'no-store' }).then(function (r) {
            if (!r.ok) return;
            if (inClient()) sessionStorage.setItem('gp-return-to', location.hash);
            location.reload();
        }).catch(function () { /* still offline: next round */ });
    }
    setInterval(recover, 5000);
    window.addEventListener('online', function () { lastTry = 0; setTimeout(recover, 1500); });
})();
