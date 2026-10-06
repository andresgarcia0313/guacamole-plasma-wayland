# guacamole-plasma-wayland

Browser access, mobile included, to your **KDE Plasma (Wayland)** desktop with
[Apache Guacamole](https://guacamole.apache.org/) 1.6 running in **rootless Podman**: the real desktop over
VNC, a web terminal over SSH and TOTP two-factor authentication. No remote desktop client needed.
Spanish documentation with more detail: [README.md](README.md).

## Highlights

- Real desktop shared with `krfb` and **one-time portal approval forever** (no "Remote control" dialog on
  every start): the unit `app-org.kde.krfb@guacamole.service` gives krfb the app id `org.kde.krfb` and the
  permission is pre-authorized in the `kde-authorized` table of the portal permission store (Plasma 6.3+).
- No frozen image: a watchdog restarts krfb when its PipeWire stream breaks.
- Web terminal without extra password and without the systemd OSC 3008 prompt garbage.
- PostgreSQL authentication with TOTP, brute-force ban and removal of the default `guacadmin` account.
- Mobile first (Chrome on Android): touchpad mouse by default, pinch-to-zoom in touchpad mode (Guacamole
  disables it there), zoomed view follows the pointer, menu and fit-to-screen buttons, screen wake lock,
  installable as an app, automatic recovery when switching from Wi-Fi to mobile data.
- Dark theme with your own name and logo. Nothing runs as root.

## Install

```bash
git clone https://github.com/andresgarcia0313/guacamole-plasma-wayland.git
cd guacamole-plasma-wayland
./install.sh            # options: --dry-run --no-desktop --no-ssh --config FILE
```

Secrets are generated into `~/.config/guacamole-plasma/config.env` (mode 600). Scan the printed QR code with
your authenticator app before the first login. The web UI listens on `127.0.0.1:8087`: put a TLS reverse
proxy in front (`extras/Caddyfile`, `extras/traefik-k3s.yaml`) and keep port 5900 (krfb) closed. With
Tailscale, ufw cannot filter the tailnet: see `extras/tailscale-firewall.nft`.

Requirements: Plasma 6.3+ on Wayland, `krfb`, Podman 4.4+ with `passt`, `python3`, `gettext-base`, `curl`
and `openssh-server` for the terminal. Tested on Kubuntu 26.04, Plasma 6.6, krfb 25.12, Podman 5.7.

## Docs

Design decisions and discarded alternatives: [docs/arquitectura.md](docs/arquitectura.md). Step by step
troubleshooting: [docs/solucion-de-problemas.md](docs/solucion-de-problemas.md) (Spanish).

## Tests

`tests/static.sh` (lint, syntax, secret leaks), `tests/dry-run.sh` (simulated install in a temporary HOME)
and `tests/stack.sh` (real install in a parallel pod on port 18087, TOTP login, purge).

## License

[Apache 2.0](LICENSE). Not affiliated with the Apache Software Foundation.
