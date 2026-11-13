# Prime-OS

[English](README.md) · [فارسی](README.fa.md) · [العربية](README.ar.md) · **Español** · [Deutsch](README.de.md)

> [!CAUTION]
> **Lee [NOTICE.md](NOTICE.md) antes de descargar, compilar, replicar o redistribuir nada.** Prime-OS es
> un prototipo independiente y sin terminar: no se redistribuye software ni controladores propietarios,
> nada está garantizado y un disco equivocado o una herramienta mal usada puede destruir datos.

**Prime-OS** es un proyecto comunitario de Linux para gaming basado en **Arch Linux** y el
compositor Wayland [Hyprland](https://hyprland.org/). El hito actual es un **prototipo de ISO en
vivo arrancable**: no es un instalador terminado ni un sistema operativo listo para producción.

> [!IMPORTANT]
> Nada de este repositorio reemplaza tu sistema operativo. La aplicación de configuración descarga
> una imagen en vivo y guarda un archivo de preferencias; no reparticiona discos, no escribe un
> USB ni instala el sistema. Prueba primero la imagen en una máquina virtual y usa un USB vacío si
> la pruebas en hardware real.

## Inicio rápido

**No necesitas Linux, Docker ni ningún paso de compilación.** El asistente descarga `os.iso` desde
la última release de GitHub y rellena la ilustración del Faravahar con el progreso real de la
descarga: un 1 % descargado es un 1 % del dibujo.

### Windows

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

### Linux y macOS

```bash
curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh | bash
```

Requisitos: **Python 3 con Tk**, **Git**, conexión a internet y espacio libre suficiente para la
imagen. Pillow se instala automáticamente en un entorno virtual privado.

El asistente:

1. consulta la última release de GitHub buscando `os.iso`;
2. la descarga en la carpeta de la aplicación con un dibujo de progreso en vivo;
3. verifica el tamaño y el SHA-256 publicado cuando la release incluye un archivo de sumas;
4. guarda tu perfil de preferencias de hardware.

Si todavía no hay ninguna release publicada, lo dice con claridad y solo guarda el perfil: nunca
finge instalar nada.

| | Windows | Linux / macOS |
| --- | --- | --- |
| Archivos de la app | `%LOCALAPPDATA%\Prime-OS` | `~/.local/share/prime-os` |
| Preferencias | `%APPDATA%\Prime-OS\setup.json` | `~/.config/prime-os/setup.json` |

## Probar la imagen en vivo

Escribe `os.iso` en un USB vacío con cualquier herramienta de escritura de imágenes, o arráncala
directamente en una máquina virtual UEFI.

```bash
# QEMU con CD-ROM de solo lectura; no se modifica nada en el equipo anfitrión
qemu-system-x86_64 -m 4G -smp 2 -cpu max -enable-kvm \
  -drive file=os.iso,media=cdrom,readonly=on -boot d
```

En Windows, `./run-windows.sh` arranca `out/os.iso` en QEMU desde Git Bash (requiere QEMU instalado).

### Atajos de teclado

| Teclas | Acción | Teclas | Acción |
| --- | --- | --- | --- |
| `Super + Enter` | Terminal (Kitty) | `Super + Q` | Cerrar ventana |
| `Super + D` | Lanzador de aplicaciones (Wofi) | `Super + F` | Pantalla completa |
| `Super + B` | Firefox | `Super + V` | Alternar flotante |
| `Super + G` | Steam | `Super + P` / `Super + J` | Pseudo-mosaico / dividir |
| `Super + N` | Configuración de red | `Super + M` | Salir de Hyprland |
| `Super + 1…9` | Cambiar de espacio de trabajo | `Super + Shift + 1…9` | Mover ventana al espacio |

## Qué incluye el prototipo

- Entorno en vivo de Arch Linux construido con el perfil oficial `archiso` (releng).
- Hyprland, Waybar, Wofi, Kitty, Dunst, NetworkManager y PipeWire/WirePlumber.
- Steam, Lutris, Firefox y los controladores Mesa/Vulkan habituales.
- Una sesión gráfica mínima en el primer arranque con el usuario normal `prime`.
- El asistente Faravahar para Windows, Linux y macOS.

**Aún no implementado:** instalador en disco, soporte de Secure Boot, flujos de actualización y
recuperación, ajuste automático de hardware y configuraciones probadas por GPU. Una sola ISO no
puede incluir todos los controladores propietarios; el soporte de NVIDIA depende del modelo.

## Integridad y seguridad

- El módulo de dibujo `you.py` se obtiene por HTTPS, se comprueba contra un SHA-256 fijado y solo se
  **analiza**, nunca se ejecuta.
- El logotipo se limita en tamaño y píxeles antes de decodificarlo y se verifica con un hash fijado.
- Las URL de descarga deben ser HTTPS y apuntar a la ruta `releases/download` de este repositorio.
- La descarga se hace en un archivo `.part` y solo se mueve a su sitio si coinciden el tamaño y,
  cuando existe, el checksum publicado.
- Los scripts verifican el SHA-256 de cada archivo que instalan.
- Los hashes están fijados en `install.sh`, `install.ps1` y `loader.py`, y deben actualizarse juntos
  cada vez que esos archivos cambien.

Comprueba tú mismo la imagen:

```bash
sha256sum os.iso          # compáralo con las notas de la release o el archivo de checksums
```

Si no coincide, no arranques la imagen y repórtalo.

## Compilar la ISO (solo desarrolladores)

Compilar es opcional y solo hace falta para modificar la imagen. Requiere Docker y varios gigabytes
libres.

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
docker run --rm --privileged \
  -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest \
  bash -lc 'pacman -Syu --noconfirm archiso && bash ./build.sh'
```

`build.sh` se niega a ejecutarse fuera de un contenedor Arch marcado explícitamente, copia el perfil
releng oficial a `.build/profile`, habilita el repositorio `multilib` para Steam **solo en ese perfil
temporal**, fusiona `profile/packages.x86_64` y escribe el resultado en `out/os.iso`.

Windows no puede compilar una ISO de Arch directamente: usa WSL2 con una distribución Arch, o
`build.ps1` con Docker Desktop.

### Compilar en CI (GitHub Actions, sin compilar en tu equipo)

1. Abre **Actions → Build and publish ISO → Run workflow**.
2. Indica una etiqueta de release (por defecto `os-preview`); se crea si no existe.
3. El trabajo compila en un contenedor Docker privilegiado, muestra **una sola barra de progreso** y
   sube `os.iso` y `os.iso.sha256` a esa release. El log completo queda como artifact.

Empujar una etiqueta `v*` hace lo mismo. No hay que compilar nada en tu máquina; un Codespace sirve
para pruebas interactivas con el mismo comando de Docker.

## Estructura del repositorio

| Ruta | Función |
| --- | --- |
| `loader.py` | Asistente: búsqueda de release, descarga de la ISO, progreso dibujado, perfil |
| `install.sh` / `install.ps1` | Instalación con un comando para Linux/macOS y Windows |
| `you.py` | Renderizador vectorial del Faravahar (se envía como dato: se analiza, no se ejecuta) |
| `faravahar.png` | Logotipo del asistente y de la sesión en vivo |
| `profile/packages.x86_64` | Paquetes extra fusionados en el perfil de archiso |
| `profile/airootfs/` | Archivos dentro de la imagen en vivo (Hyprland, Waybar, autologin, setup) |
| `build.sh` / `build.ps1` | Compilación reproducible de la ISO con Docker |
| `run-windows.sh` | Arranca la ISO compilada en QEMU desde Git Bash |
| `requirements.txt` | Dependencia de Python (`Pillow`) |
| `NOTICE.md` | Qué es y qué no es el proyecto: licencias, marcas, seguridad, estado |
| `.github/` | Workflow de Actions que compila la ISO y la publica en las releases |

La sesión en vivo se inicia una sola vez, en `tty1`, mediante el drop-in de autologin de `getty` y
`/etc/skel/.bash_profile`; `prime-os-live-setup` crea el usuario sin privilegios `prime` e instala
la configuración canónica `/etc/prime-os/hyprland.conf`.

## Estado del proyecto

Esto es un punto de partida, no un sistema de gaming terminado. Próximos hitos: validar la primera
imagen publicada en hardware real, corregir problemas de arranque y de paquetes, diseñar un
instalador y después añadir perfiles de gaming probados y flujos de actualización y recuperación.
Los informes de pruebas de hardware y las contribuciones son bienvenidos.

## Contribuir

- Mantén la honestidad de la imagen: nada de afirmaciones de «sin lag» ni cifras de rendimiento sin
  mediciones.
- Prueba en una máquina virtual antes que en hardware físico y nunca pidas a nadie que borre un USB
  con datos.
- Si cambias `loader.py`, `you.py` o `faravahar.png`, actualiza los hashes fijados en los instaladores
  en el mismo commit: los instaladores fallan a propósito.
- Reporta tu modelo de GPU, versión de controlador y qué funcionó o falló.

## Licencia

Publicado bajo la [Licencia MIT](LICENSE): uso, modificación y redistribución libres, sin garantía.

El rendimiento en juegos y la compatibilidad de hardware dependen de tu GPU, los controladores, el
juego y el equipo; no pueden garantizarse.
