<!-- Idioma del documento: español de Colombia (es-CO) -->
# Solución de problemas

Siglas: TOTP (Time-based One-Time Password, contraseña de un solo uso basada en tiempo), VNC (Virtual
Network Computing, computación en red virtual), QR (Quick Response, código de respuesta rápida) y NAT
(Network Address Translation, traducción de direcciones de red).

## El cuadro «Control remoto» vuelve a pedir aprobación

1. Comprueba que `krfb` corre con identificador de aplicación:
   `cat /proc/$(systemctl --user show app-org.kde.krfb@guacamole -p MainPID --value)/cgroup`
   debe terminar en `app-org.kde.krfb@guacamole.service`.
2. Comprueba el permiso guardado (debe mostrar `'org.kde.krfb': ['yes']`):
   `gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore --object-path /org/freedesktop/impl/portal/PermissionStore --method org.freedesktop.impl.portal.PermissionStore.Lookup kde-authorized remote-desktop`
3. Si el registro muestra `MegaAuth: Failed to lookup permissions`, el permiso o el identificador
   faltan: `journalctl --user --since -10min | grep MegaAuth`.
4. Requiere Plasma 6.3 o superior. No apliques el permiso con `sudo`: el almacén es por usuario.

## La imagen del escritorio queda congelada

- `journalctl --user -u krfb-watchdog` muestra cuándo se reinició `krfb` y por qué.
- Estado del flujo de pantalla: `pw-dump | grep -A3 krfb`; sano es `running`.
- Si Guacamole reabre una pestaña vieja, entra desde la lista de conexiones: la extensión ya lleva a la
  lista tras iniciar sesión.

## No se ve el puntero

La conexión VNC debe tener `cursor=local`; con `remote`, `guacd` espera que el servidor pinte el puntero y
`krfb` en Wayland no lo hace. `python3 bin/sync-db.py` vuelve a aplicar los parámetros.

## No puedo hacer zoom con el pellizco en el móvil

Recarga la página para cargar la extensión. En modo touchpad el pellizco lo aporta la extensión; en modo
pantalla táctil es el de Guacamole. El botón ⤢ vuelve a ajustar el escritorio a la pantalla.

## El código TOTP no se acepta

- La hora del teléfono y la del equipo deben estar sincronizadas (el código cambia cada 30 s).
- Un mismo código no se puede usar dos veces seguidas: espera al siguiente.
- `python3 bin/totp-qr.py` vuelve a mostrar el QR.
- Tras 5 intentos fallidos la dirección queda bloqueada 15 minutos (extensión `ban`).

## Texto `start=...;machineid=...` en la terminal

Es el prompt de systemd. La conexión de terminal arranca bash con `web-shell-rc.sh`, que lo omite; si
aparece, vuelve a ejecutar `python3 bin/sync-db.py`.

## Desde la red de casa la página a veces no carga

Muchos enrutadores domésticos fallan al devolver el tráfico hacia su propia dirección pública (NAT de
vuelta o *hairpin*). Fuera de casa funciona. Solución: un DNS (Domain Name System, sistema de nombres de
dominio) local que resuelva tu dominio a la dirección del proxy dentro de la red.

## La página da error y no se recupera tras cambiar de WiFi a datos

La extensión revisa cada 5 s y, cuando el servidor vuelve a responder, recarga y regresa al mismo
escritorio. Guacamole 1.6 no reabre el túnel si la página se carga ya en la ruta del escritorio, por eso
entra primero por la lista.

## Diagnóstico general

```bash
systemctl --user status guac-web guac-db guac-guacd app-org.kde.krfb@guacamole krfb-watchdog
podman logs --since 10m guac-web
podman logs --since 10m guac-guacd
ss -tlnp | grep -E ':(5900|8087) '
```
