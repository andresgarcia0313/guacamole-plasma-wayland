/* Login flow fixes for Guacamole 1.6 (guacamole-plasma-wayland) */
(function () {
    // Tab icon
    function setIcon() {
        var links = document.querySelectorAll('link[rel~="icon"], link[rel="shortcut icon"]');
        if (!links.length) {
            var l = document.createElement('link');
            l.rel = 'icon';
            document.head.appendChild(l);
            links = [l];
        }
        links.forEach(function (l) { l.type = 'image/png'; l.href = 'app/ext/gplasma/images/icon-192.png'; });
    }
    setIcon();
    document.addEventListener('DOMContentLoaded', setIcon);

    // Always land on the connection list: never restore an old client screen (it looks frozen).
    function toList() {
        if (/^#\/client\//.test(location.hash)) location.hash = '#/';
    }
    toList();
    // While the login form is shown, a pending client route becomes the list
    setInterval(function () {
        if (document.querySelector('.login-ui')) toList();
    }, 300);

    // After an automatic network recovery (mobile.js) go back to the same desktop. Guacamole 1.6 does
    // not open the tunnel when the page is loaded directly on the client route: enter from the list.
    try {
        var target = sessionStorage.getItem('gp-return-to');
        if (target && /^#\/client\//.test(target)) {
            sessionStorage.removeItem('gp-return-to');
            var tries = 0;
            var wait = setInterval(function () {
                tries++;
                var ready = document.querySelector('.connection-list-ui .connection');
                if (ready || tries > 40) {
                    clearInterval(wait);
                    if (ready) location.hash = target;
                }
            }, 250);
        }
    } catch (e) { /* no sessionStorage: stay on the list */ }
})();
