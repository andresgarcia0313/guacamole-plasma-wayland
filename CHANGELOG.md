<!-- Idioma del documento: español de Colombia (es-CO) -->
# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado semántico.

## [1.0.1] - 2026-10-06

### Añadido
- `docs/arquitectura.md`: flujo, decisiones y alternativas descartadas.
- `docs/solucion-de-problemas.md`: diagnóstico de cada síntoma conocido.

## [1.0.0] - 2026-10-06

### Añadido
- Instalador y desinstalador sin `sudo` (Podman sin root, Quadlet y `systemd --user`), con modo de prueba
  en seco y opciones para instalar solo la web o sin terminal.
- Escritorio KDE Plasma con Wayland por VNC con `krfb`, con aprobación única del portal (tabla
  `kde-authorized`) y vigilante del flujo de pantalla de PipeWire.
- Terminal web por SSH con llave dedicada válida solo desde el loopback y sin el ruido del prompt de systemd.
- Autenticación con PostgreSQL y doble factor TOTP, con secreto generado y código QR para registrarlo.
- Extensión de Guacamole: tema oscuro, nombre y logo configurables, español en el doble factor y mejoras
  para el móvil (touchpad, pellizco, vista que sigue al puntero, botones, pantalla encendida, aplicación
  instalable y reconexión automática).
- Ejemplos de publicación con Caddy y Traefik (k3s) y de cortafuegos para Tailscale.
- Pruebas estáticas, de instalación simulada y de instalación real con login TOTP.
