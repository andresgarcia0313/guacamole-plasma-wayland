<!-- Idioma del documento: español de Colombia (es-CO). English versión: README.en.md -->
# guacamole-plasma-wayland

Acceso desde el navegador, incluido el móvil, a tu escritorio **KDE Plasma con Wayland**, usando
[Apache Guacamole](https://guacamole.apache.org/) 1.6 en contenedores **Podman sin root**. Incluye la
pantalla real del escritorio por VNC (Virtual Network Computing, computación en red virtual) y una terminal
por SSH (Secure Shell, intérprete de órdenes seguro), con doble factor TOTP (Time-based One-Time Password,
contraseña de un solo uso basada en tiempo). No hace falta instalar un cliente de escritorio remoto.

Nació de montar Guacamole sobre Plasma 6 con Wayland y chocar con problemas que casi nadie documenta.
Cada uno quedó resuelto y probado (ver [Problemas resueltos](#problemas-resueltos)).

## Qué obtienes

- **Escritorio real** compartido con `krfb`, el servidor VNC de KDE, con **una sola aprobación del portal
  para siempre**: no vuelve a salir el cuadro «Control remoto» en cada arranque.
- **Imagen siempre viva**: un vigilante reinicia `krfb` si el flujo de pantalla de PipeWire se rompe
  (monitor desconectado, pantalla apagada, suspensión).
- **Terminal web** sin contraseña adicional y sin el texto basura que imprime el prompt de systemd.
- **Doble factor TOTP** con base de datos PostgreSQL propia y bloqueo tras 5 intentos fallidos.
- **Pensado para el móvil** (Chrome en Android): ratón tipo touchpad, pellizco para hacer zoom, la vista
  sigue al puntero, botón de menú y de «ajustar a la pantalla», pantalla siempre encendida, instalable
  como aplicación y reconexión automática al cambiar de WiFi a datos.
- **Tema oscuro** con tu nombre y tu logo en lugar de «Apache Guacamole».
- Todo corre como tu usuario (`systemd --user` y Quadlet). Ningún paso del instalador usa `sudo`.

## Requisitos

| Componente | Versión | Paquetes en Debian, Ubuntu o Kubuntu |
|---|---|---|
| KDE Plasma con Wayland | 6.3 o superior (permiso del portal) | `krfb`, `libglib2.0-bin` |
| Podman sin root con Quadlet | 4.4 o superior | `podman`, `passt` |
| Herramientas | | `python3`, `gettext-base`, `curl`, `openssh-server` (para la terminal) |
| Opcional | | módulo de Python `qrcode` (muestra el código QR en la terminal) |

Probado en Kubuntu 26.04 con Plasma 6.6, krfb 25.12, Podman 5.7 y Guacamole 1.6.0.

## Instalación

```bash
git clone https://github.com/andresgarcia0313/guacamole-plasma-wayland.git
cd guacamole-plasma-wayland
./install.sh
```

El instalador crea `~/.config/guacamole-plasma/config.env` (permisos 600) con contraseñas aleatorias,
construye todo, arranca los servicios y muestra el código QR (Quick Response, código de respuesta rápida) del doble factor. **Escanéalo con tu
aplicación de autenticación antes de entrar.** Para cambiar el usuario, el nombre, el logo o el puerto,
edita ese archivo (hay un ejemplo comentado en `config.example.env`) y vuelve a ejecutar `./install.sh`.

| Opción | Efecto |
|---|---|
| `--dry-run` | Genera los archivos sin descargar imágenes, arrancar servicios ni tocar el portal |
| `--no-desktop` | Solo la web y la terminal (sin `krfb` ni permiso del portal) |
| `--no-ssh` | Sin llave SSH ni conexión de terminal |
| `--config ARCHIVO` | Usa otro archivo de configuración |

Desinstalar: `./uninstall.sh` (conserva datos y configuración) o `./uninstall.sh --purge` (borra todo:
volumen de la base, llave SSH de `authorized_keys`, permiso del portal y configuración).

## Publicarlo de forma segura

La web queda en `http://127.0.0.1:8087`. Para usarla desde fuera, pon delante un proxy inverso con TLS
(Transport Layer Security, cifrado de la conexión). En `extras/` hay ejemplos:

- `Caddyfile`: lo más simple, en el mismo equipo; Caddy obtiene el certificado solo.
- `traefik-k3s.yaml`: el escritorio publicado por un Traefik de k3s, por ejemplo a través de Tailscale.
  Ajusta `GP_BIND` a la dirección que verá Traefik y `GP_TRUSTED_PROXY` a la dirección de Traefik.
- `tailscale-firewall.nft`: Tailscale acepta todo lo que entra por `tailscale0` **antes** que ufw, así
  que las reglas de ufw no lo restringen. Esta tabla de nftables sí lo hace.

`krfb` escucha en el puerto 5900 de todas las interfaces y no permite elegir una. **Mantén el 5900
cerrado** en tu cortafuegos: el contenedor llega a `krfb` por el loopback del equipo.

## Uso desde el móvil

| Gesto o botón | Acción |
|---|---|
| Arrastrar un dedo | Mueve el puntero (modo touchpad, clic preciso) |
| Tocar | Clic izquierdo; dos dedos: clic derecho; dos dedos en vertical: rueda |
| Pellizcar | Zoom; con zoom, la vista sigue al puntero |
| ⤢ | Vuelve a ajustar el escritorio a la pantalla (aparece solo con zoom) |
| ☰ | Abre el menú de Guacamole: teclado, portapapeles, desconectar |
| Menú de Chrome, «Instalar aplicación» | Abre sin la barra del navegador |

## Problemas resueltos

Detalle de diseño en [docs/arquitectura.md](docs/arquitectura.md) y diagnóstico paso a paso en
[docs/solucion-de-problemas.md](docs/solucion-de-problemas.md).

| Problema | Causa | Solución |
|---|---|---|
| El cuadro «Control remoto» pide aprobar en cada arranque | `krfb` 25.12 no usa token de restauración del portal y corre sin identificador de aplicación | Unidad `app-org.kde.krfb@guacamole.service` y permiso previo en la tabla `kde-authorized` del almacén de permisos (Plasma 6.3+) |
| La imagen del escritorio queda congelada | El flujo de PipeWire de `krfb` deja de entregar imágenes | `krfb-watchdog.sh` lo detecta con `pw-dump` y reinicia `krfb`, sin coste porque ya no pregunta |
| KRdp (escritorio remoto de Plasma) no funciona con Guacamole | KRdp exige H.264 por el canal gráfico de RDP (Remote Desktop Protocol) y `guacd` no lo ofrece | VNC con `krfb` |
| El puntero no se ve | Con `cursor=remote`, `guacd` espera que el servidor pinte el puntero y `krfb` en Wayland no lo hace | `cursor=local` |
| `krfb` rechaza la contraseña | Guarda las claves ofuscadas (`KStringHandler::obscure`) | El instalador escribe la contraseña ofuscada; VNC solo usa 8 caracteres |
| El pellizco no hace zoom | Guacamole 1.6 lo desactiva a propósito en modo touchpad | Pellizco propio con la misma fórmula de Guacamole |
| Tras cortarse la red, la pantalla queda en error | Guacamole 1.6 no abre el túnel si la página carga ya en la ruta del escritorio | Recarga, entra desde la lista y vuelve al mismo escritorio |
| Texto `start=...;machineid=...` en la terminal | El prompt de systemd (secuencias OSC 3008, Operating System Command o comando del sistema operativo) que el emulador web no entiende | Arranque propio de bash sin ese contexto |
| Las variables `POSTGRES_*` confunden a Guacamole | Están obsoletas desde Guacamole 1.5.2 | Archivos de entorno separados para la base y para la web |
| Cuenta `guacadmin` con clave `guacadmin` | La crea el esquema oficial | Se borra en cada sincronización |
| El contenedor no llega a servicios del equipo | `host.containers.internal` no apunta al loopback | Red `pasta` con `--map-host-loopback` |

## Operación

```bash
systemctl --user status guac-web guac-db guac-guacd app-org.kde.krfb@guacamole krfb-watchdog
journalctl --user -u krfb-watchdog          # reinicios del flujo de pantalla
python3 bin/totp-qr.py                       # vuelve a mostrar el QR del doble factor
python3 bin/sync-db.py                       # aplica cambios de usuario o contraseña de config.env
```

## Pruebas

```bash
tests/static.sh    # sintaxis, shellcheck, Python, JavaScript, JSON, documentación y fugas de secretos
tests/dry-run.sh   # instalación simulada en un HOME temporal
tests/stack.sh     # instalación real en un pod paralelo (puerto 18087), login con TOTP y purga
```

## Seguridad

- No se publica ningún secreto: todos se generan al instalar y quedan en `config.env` (600).
- La llave SSH de la terminal web solo vale desde `127.0.0.1` y sin reenvíos.
- La base de datos no se publica fuera del pod.
- Cualquier persona con el usuario, la contraseña **y** el código TOTP controla tu escritorio: usa una
  contraseña fuerte y protege el teléfono con el autenticador.

## Licencia

[Apache 2.0](LICENSE). Apache Guacamole es un proyecto de la Apache Software Foundation; este repositorio
no está afiliado a ella.

## Control de cambios

| Versión | Fecha | Autor | Descripción del cambio |
|---|---|---|---|
| 1.0.0 | 2026-10-06 | Andrés García | Primera versión pública |
| 1.0.1 | 2026-10-06 | Andrés García | Documentos de arquitectura y de solución de problemas |
