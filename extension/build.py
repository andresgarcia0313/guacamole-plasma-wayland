#!/usr/bin/env python3
"""Builds the Guacamole extension (guacamole-plasma.jar) with the configured name and optional logo.

Usage: build.py OUTPUT.jar   (reads GP_APP_NAME and GP_LOGO from the environment)
"""
import json
import os
import pathlib
import sys
import zipfile

HERE = pathlib.Path(__file__).resolve().parent


def webmanifest(name):
    return json.dumps({
        "id": "/", "name": name, "short_name": name[:12], "start_url": "/", "scope": "/",
        "display": "standalone", "orientation": "any", "background_color": "#0b1020",
        "theme_color": "#0b1020", "prefer_related_applications": False,
        "icons": [
            {"src": "/app/ext/gplasma/images/icon-192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "/app/ext/gplasma/images/icon-512.png", "sizes": "512x512", "type": "image/png",
             "purpose": "any maskable"}]}, indent=4, ensure_ascii=False)


def main():
    output = pathlib.Path(sys.argv[1])
    name = os.environ.get("GP_APP_NAME") or "Remote Desktop"
    logo = os.environ.get("GP_LOGO") or ""
    manifest = json.loads((HERE / "guac-manifest.json").read_text())
    if logo:
        if not pathlib.Path(logo).is_file():
            sys.exit(f"logo not found: {logo}")
        manifest["css"].append("css/logo.css")
        manifest["resources"]["images/logo.png"] = "image/png"
    output.parent.mkdir(parents=True, exist_ok=True)
    escaped = json.dumps(name, ensure_ascii=False)[1:-1]
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("guac-manifest.json", json.dumps(manifest, indent=4))
        for path in manifest["css"] + manifest["js"]:
            z.write(HERE / path, path)
        for path in manifest["translations"]:
            z.writestr(path, (HERE / path).read_text(encoding="utf-8").replace("@APP_NAME@", escaped))
        for path in ("images/icon-192.png", "images/icon-512.png"):
            z.write(HERE / path, path)
        z.writestr("app.webmanifest", webmanifest(name))
        if logo:
            z.write(logo, "images/logo.png")
    output.chmod(0o644)
    print(f"built {output} ({output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
