#!/usr/bin/env python3
"""Shows the TOTP enrollment data of the configured user: otpauth URI, manual key and a QR code.

The QR code is printed in the terminal (and saved as PNG) when the "qrcode" Python module is available.
Usage: totp-qr.py [OUTPUT.png]
"""
import os
import shlex
import sys
import urllib.parse

CONFIG = os.environ.get("GP_CONFIG", os.path.expanduser("~/.config/guacamole-plasma/config.env"))


def read_config():
    values = {}
    for line in open(CONFIG, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, raw = line.split("=", 1)
            parsed = shlex.split(raw, comments=True)
            values[key.strip()] = parsed[0] if parsed else ""
    return values


def main():
    cfg = read_config()
    issuer = cfg.get("GP_TOTP_ISSUER", "Guacamole Plasma")
    label = urllib.parse.quote(f"{issuer}:{cfg['GP_USER']}")
    uri = (f"otpauth://totp/{label}?secret={cfg['GP_TOTP_SECRET']}&issuer={urllib.parse.quote(issuer)}"
           "&algorithm=SHA1&digits=6&period=30")
    print("Manual key (SHA1, 6 digits, 30 s):", cfg["GP_TOTP_SECRET"])
    print("URI:", uri)
    try:
        import qrcode
    except ImportError:
        print("Install the Python module 'qrcode' to see the QR code (pip install qrcode).")
        return
    qr = qrcode.QRCode(border=2)
    qr.add_data(uri)
    qr.print_ascii(invert=True)
    if len(sys.argv) > 1:
        old = os.umask(0o077)
        with open(sys.argv[1], "wb") as handle:
            qr.make_image().save(handle)
        os.umask(old)
        print("QR saved to", sys.argv[1])


if __name__ == "__main__":
    main()
