<!-- Idioma del documento: español de Colombia (es-CO) -->
# Arquitectura y decisiones

Siglas: VNC (Virtual Network Computing, computación en red virtual), SSH (Secure Shell, intérprete de
órdenes seguro), TOTP (Time-based One-Time Password, contraseña de un solo uso basada en tiempo), TLS
(Transport Layer Security, cifrado de la conexión), HTTPS (protocolo web cifrado con TLS) y QR (Quick
Response, código de respuesta rápida).

## Flujo

```
Navegador o móvil
   |  HTTPS (proxy inverso con TLS: Caddy, Traefik...)
   v
127.0.0.1:8087 (o la dirección de GP_BIND)
   |
   v  pod de Podman sin root "guac" (red pasta con --map-host-loopback)
   |-- guac-web   Apache Guacamole 1.6 + extensión gplasma (tema, móvil, gestos)
   |-- guac-guacd proxy de protocolos
   |-- guac-db    PostgreSQL: usuario, conexiones, secreto TOTP (no se publica fuera del pod)
   |
   v  host.containers.internal = loopback del equipo
   |-- 127.0.0.1:5900  krfb (VNC) -> pantalla real de Plasma por PipeWire
   |-- 127.0.0.1:22    sshd -> terminal web con llave dedicada
```

Todo corre como el usuario: Quadlet genera los servicios de `systemd --user`. `krfb` corre como
`app-org.kde.krfb@guacamole.service` y lo vigila `krfb-watchdog.service`.

## Decisiones

| Decisión | Motivo |
|---|---|
| VNC con `krfb` y no RDP (Remote Desktop Protocol) con KRdp | KRdp exige H.264 por el canal gráfico de RDP y `guacd` 1.6 no lo ofrece: la conexión se cierra al negociar |
| Aprobación única del portal con la tabla `kde-authorized` | `krfb` 25.12 no usa token de restauración: sin esto pide aprobar en cada arranque y no sirve para acceso desatendido |
| Identificador de aplicación por el nombre de la unidad (`app-<id>@<instancia>.service`) | Es como el portal identifica a una aplicación del equipo; sin él no puede recordar ningún permiso |
| Vigilante que reinicia `krfb` solo si el flujo se rompe | Reiniciar por rutina generaba aprobaciones repetidas; con el permiso previo reiniciar ya no cuesta nada |
| PostgreSQL y no `user-mapping.xml` | El doble factor TOTP necesita guardar atributos por usuario, y eso exige una base JDBC (Java Database Connectivity, conexión de Java a bases de datos) |
| Secreto TOTP generado por el instalador | Evita depender del QR que muestra Guacamole en el primer inicio de sesión |
| Red `pasta` con `--map-host-loopback` | Permite que `krfb` escuche solo para el equipo y que el contenedor llegue a él por el loopback |
| Sin cambios en los tiempos de espera de Traefik | Una sesión inactiva de 241 s siguió abierta: los mensajes `sync` de Guacamole mantienen vivo el WebSocket |
| Pellizco propio en modo touchpad | Guacamole 1.6 lo desactiva a propósito en ese modo; el modo pantalla táctil tiene un fallo con el zoom (GUACAMOLE-1529) |

## Alternativas descartadas

| Alternativa | Por qué no |
|---|---|
| `x11vnc` | Solo ve sesiones X11, no Wayland |
| `wayvnc` | Necesita protocolos de wlroots que KWin no ofrece |
| Pulsar «Aprobar» por accesibilidad (AT-SPI) | Obliga a activar la accesibilidad de todo el escritorio |
| KRdp con FreeRDP recompilado con H.264 | Hay reportes de éxito parcial y de fallos; demasiado frágil para un instalador |
| Monitor virtual (`krfb-virtualmonitor`) | Es otra pantalla, no la que el usuario está usando |
