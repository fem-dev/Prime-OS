# Prime-OS

[English](README.md) · [فارسی](README.fa.md) · [العربية](README.ar.md) · [Español](README.es.md) · **Deutsch**

**Prime-OS** ist ein von der Community entwickeltes Gaming-Linux auf Basis von **Arch Linux** und
dem Wayland-Compositor [Hyprland](https://hyprland.org/). Der aktuelle Meilenstein ist ein
**bootfähiger Live-ISO-Prototyp** – kein fertiger Installer und kein produktionsreifes Betriebssystem.

> [!IMPORTANT]
> Nichts in diesem Repository ersetzt dein Betriebssystem. Das Setup lädt ein Live-Image herunter
> und speichert eine Präferenzdatei; es partitioniert keine Datenträger, beschreibt keinen USB-Stick
> und installiert nichts. Teste das Image zuerst in einer virtuellen Maschine und nutze für Tests auf
> echter Hardware einen leeren USB-Stick.

## Schnellstart

**Du brauchst kein Linux, kein Docker und keinen Build-Schritt.** Der Assistent lädt `os.iso` aus
dem neuesten GitHub-Release und füllt die Faravahar-Grafik im Takt des echten Downloads: ein Prozent
Download ist ein Prozent der Zeichnung.

### Windows

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

### Linux und macOS

```bash
curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh | bash
```

Voraussetzungen: **Python 3 mit Tk**, **Git**, eine Internetverbindung und genug freier Speicher für
das Image. Pillow wird automatisch in einer privaten virtuellen Umgebung installiert.

Der Assistent:

1. prüft das neueste GitHub-Release auf `os.iso`;
2. lädt es mit einer live gezeichneten Fortschrittsanzeige in den Programmordner;
3. prüft die Größe und, sofern das Release eine Prüfsummendatei enthält, den veröffentlichten SHA-256;
4. speichert dein Hardware-Profil.

Existiert noch kein Release, sagt der Assistent das offen und speichert nur das Profil – er täuscht
niemals eine Installation vor.

| | Windows | Linux / macOS |
| --- | --- | --- |
| Programmdateien | `%LOCALAPPDATA%\Prime-OS` | `~/.local/share/prime-os` |
| Einstellungen | `%APPDATA%\Prime-OS\setup.json` | `~/.config/prime-os/setup.json` |

## Live-Image testen

Schreibe `os.iso` mit einem beliebigen Image-Tool auf einen leeren USB-Stick oder starte es direkt in
einer UEFI-Virtual-Maschine.

```bash
# QEMU mit schreibgeschütztem CD-ROM; am Host ändert sich nichts
qemu-system-x86_64 -m 4G -smp 2 -cpu max -enable-kvm \
  -drive file=os.iso,media=cdrom,readonly=on -boot d
```

Unter Windows startet `./run-windows.sh` die Datei `out/os.iso` aus der Git Bash in QEMU (QEMU muss
installiert sein).

### Tastenkürzel

| Tasten | Aktion | Tasten | Aktion |
| --- | --- | --- | --- |
| `Super + Enter` | Terminal (Kitty) | `Super + Q` | Fenster schließen |
| `Super + D` | Programmstarter (Wofi) | `Super + F` | Vollbild |
| `Super + B` | Firefox | `Super + V` | Schwebend umschalten |
| `Super + G` | Steam | `Super + P` / `Super + J` | Pseudo-Kachel / teilen |
| `Super + N` | Netzwerkeinstellungen | `Super + M` | Hyprland beenden |
| `Super + 1…9` | Workspace wechseln | `Super + Shift + 1…9` | Fenster auf Workspace verschieben |

## Was der Prototyp enthält

- Arch-Linux-Live-Umgebung, gebaut mit dem offiziellen `archiso`-Profil (releng).
- Hyprland, Waybar, Wofi, Kitty, Dunst, NetworkManager und PipeWire/WirePlumber.
- Steam, Lutris, Firefox und die üblichen Mesa/Vulkan-Treiber.
- Eine minimale grafische Sitzung beim ersten Start als normaler, unprivilegierter Benutzer `prime`.
- Der Faravahar-Assistent für Windows, Linux und macOS.

**Noch nicht umgesetzt:** Datenträger-Installer, Secure-Boot-Unterstützung, Update- und
Wiederherstellungsabläufe, automatische Hardware-Optimierung und getestete Konfigurationen pro GPU.
Eine einzelne ISO kann nicht alle proprietären Treiber enthalten; NVIDIA-Unterstützung hängt vom
Kartenmodell ab.

## Integrität und Sicherheit

- Das Zeichenmodul `you.py` wird über HTTPS geladen, gegen einen festen SHA-256 geprüft und nur
  **geparst**, niemals ausgeführt.
- Das Logo wird vor dem Dekodieren in Größe und Pixelzahl begrenzt und gegen einen festen Hash geprüft.
- Download-URLs müssen HTTPS sein und auf den Pfad `releases/download` dieses Repositories zeigen.
- Downloads landen in einer `.part`-Datei und werden erst verschoben, wenn Größe und – falls
  veröffentlicht – die Prüfsumme übereinstimmen.
- Die Skripte prüfen den SHA-256 jeder Datei, die sie installieren.
- Die Hashes sind in `install.sh`, `install.ps1` und `loader.py` fest verdrahtet und müssen bei jeder
  Änderung dieser Dateien gemeinsam aktualisiert werden.

Prüfe das Image selbst:

```bash
sha256sum os.iso          # mit den Release-Notes oder der Prüfsummendatei vergleichen
```

Bei einer Abweichung das Image nicht starten, sondern melden.

## ISO bauen (nur für Entwickler)

Der Build ist optional und nur nötig, wenn du das Image selbst ändern willst. Er braucht Docker und
mehrere Gigabyte freien Speicher.

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
docker run --rm --privileged \
  -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest \
  bash -lc 'pacman -Syu --noconfirm archiso && bash ./build.sh'
```

`build.sh` weigert sich außerhalb eines ausdrücklich markierten Arch-Containers zu laufen, kopiert das
offizielle releng-Profil nach `.build/profile`, aktiviert das `multilib`-Repository für Steam **nur in
diesem temporären Profil**, führt `profile/packages.x86_64` zusammen und schreibt das Ergebnis nach
`out/os.iso`.

Windows kann eine Arch-ISO nicht direkt bauen – nutze WSL2 mit einer Arch-Distribution oder
`build.ps1` mit Docker Desktop.

## Repository-Aufbau

| Pfad | Zweck |
| --- | --- |
| `loader.py` | Assistent: Release-Suche, ISO-Download, gezeichneter Fortschritt, Profil |
| `install.sh` / `install.ps1` | Ein-Befehl-Installation für Linux/macOS und Windows |
| `you.py` | Vektor-Renderer für den Faravahar (als Datum ausgeliefert: geparst, nicht ausgeführt) |
| `faravahar.png` | Logo des Assistenten und der Live-Sitzung |
| `profile/packages.x86_64` | Zusätzliche Pakete, die ins archiso-Profil eingemischt werden |
| `profile/airootfs/` | Dateien im Live-Image (Hyprland, Waybar, Autologin, Setup) |
| `build.sh` / `build.ps1` | Reproduzierbarer ISO-Build in Docker |
| `run-windows.sh` | Startet die gebaute ISO in QEMU aus der Git Bash |
| `requirements.txt` | Python-Abhängigkeit (`Pillow`) |

Die Live-Sitzung startet genau einmal auf `tty1` über das `getty`-Autologin-Drop-in zusammen mit
`/etc/skel/.bash_profile`; `prime-os-live-setup` legt den unprivilegierten Benutzer `prime` an und
installiert die maßgebliche Konfiguration `/etc/prime-os/hyprland.conf`.

## Projektstatus

Das ist ein Ausgangspunkt, kein fertiges Gaming-Betriebssystem. Nächste Meilensteine: das erste
veröffentlichte Image auf echter Hardware validieren, Start- und Paketprobleme beheben, einen
Installer entwerfen und danach getestete Gaming-Profile sowie Update- und Wiederherstellungsabläufe
ergänzen. Hardware-Testberichte und Beiträge sind willkommen.

## Mitwirken

- Bleib ehrlich: keine „lag-frei“-Versprechen und keine Leistungszahlen ohne Messung.
- Teste zuerst in einer virtuellen Maschine und verlange nie, einen USB-Stick mit Daten zu löschen.
- Wenn du `loader.py`, `you.py` oder `faravahar.png` änderst, aktualisiere im selben Commit die festen
  Hashes in den Installern – die Installer schlagen absichtlich fehl.
- Melde GPU-Modell, Treiberversion und was funktioniert hat und was nicht.

## Lizenz

Veröffentlicht unter der [MIT-Lizenz](LICENSE) – freie Nutzung, Änderung und Weitergabe, ohne Gewähr.

Spielleistung und Hardware-Kompatibilität hängen von GPU, Treibern, Spiel und Hardware ab und können
nicht garantiert werden.
