# Prime-OS

> **Note:** this translation predates the setup-installer layout. The commands still work; the structure sections describe an older image. [README.md](README.md) is the reference.


[English](README.md) · [Italiano]· [العربية](README.ar.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [Farsi](README.fa.md) · [Français](README.fr.md)

> [!CAUTION]
> **Leggi [NOTICE.md](NOTICE.md) prima di scaricare, costruire, specchiare o ridistribuire qualsiasi cosa.** Prime-OS è un prototipo incompleto e non affiliato: nessun software o driver proprietario viene ridistribuito, nulla non è garantito, e una scelta errata di unità o un uso improprio degli strumenti può distruggere dati.

**Prime-OS** è un progetto della community che costruisce un sistema operativo di gaming basato su **Arch Linux** e il compositore Wayland **Hyprland**. L'obiettivo corrente è un'**ISO live bootable** — non un installatore completo e non un sistema operativo pronto per la produzione.

> [!IMPORTANT]
> Nessuna parte di questo repository sostituisce il tuo sistema operativo. L'applicazione di configurazione scarica un'immagine live e salva un file di preferenze; non partitiona un disco, non scrive su una chiavetta USB e non installa Prime-OS. Testa prima l'image in una macchina virtuale, e usa una chiavetta USB di riserva se testi su hardware reale.

## Avvio rapido

**Non hai bisogno di Linux, Docker o nessun passaggio di build.** L'applicazione di configurazione scarica l'`os.iso` pubblicato nell'ultima Release GitHub e riempie l'artwork Faravahar con la progressione di download reale : un percento scaricato è un percento del disegno.

### Windows

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

> [!TIP]
> **Se il comando Windows fallisce con un errore di rete** (`Unable to connect to the remote
> server`, `Could not connect to server` o un timeout), il problema è la connessione a GitHub, non
> lo script: **attiva una VPN e riesegui lo stesso comando**. Se una VPN è già attiva e continua a
> fallire, **disattiva la VPN** (o cambia server) e riprova — alcune VPN, filtri DNS e reti
> aziendali bloccano `raw.githubusercontent.com` e `github.com`. Poi apri `https://github.com` nel
> browser per verificare la connessione e riesegui il comando.

### Linux

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install-mac.sh)
```

## Sorgente di download

Prime-OS ha esattamente **una** sorgente ufficiale: le **release GitHub** del progetto. Nessun mirror
né terze parti, quindi un'immagine può arrivare solo dal repository che pubblica il suo SHA-256.
**Invio** avvia, **Esc** esce.

## Risoluzione dei problemi

Vedi il [riferimento errori in DOCS.md](DOCS.md): ogni guasto noto con causa e soluzione.

**Prerequisiti:** **Python 3 con Tk**, **curl**, una connessione Internet, e abbastanza spazio libero per l'image. Pillow è installato automaticamente in un ambiente virtuale privato.

L'applicazione di configurazione effectue queste azioni :

1. Verifica l'ultima Release GitHub per `os.iso` ;
2. La scarica nella cartella dell'application con una barra de progressione en direct ;
3. Verifie la taille, et la SHA-256 publiée lorsque le release inclut un fichier de checksum ;
4. Enregistre votre profil matériel.

Si aucune release n'a été publiée encore, l'application le dit simplement et enregistre seulement le profil — elle n'essaie pas de faire semblant d'installer un OS.

| | Windows | Linux / macOS |
| --- | --- | --- |
| Fichiers de l'app | `%LOCALAPPDATA%\\Prime-OS` | `~/.local/share/prime-os` |
| Préférences | `%APPDATA%\\Prime-OS\\setup.json` | `~/.config/prime-os/setup.json` |

## Essayer l'image live

Écrivez `os.iso` sur une clé USB vide avec un outil d'écriture d'image, ou démarrez-la directement dans une machine virtuelle UEFI.

```bash
# QEMU, CD-ROM en lecture seule, rien sur l'hôte n'est modifié
qemu-system-x86_64 -m 4G -smp 2 -cpu max -enable-kvm \\
  -drive file=os.iso,media=cdrom,readonly=on -boot d
```

Sous Windows, `./run-windows.sh` démarre `out/os.iso` depuis Git Bash (QEMU requis).

### Raccourcis clavier

| Touches | Action | Touches | Action |
| --- | --- | --- | --- |
| `Super + Enter` | Terminal (Kitty) | `Super + Q` | Fermer la fenêtre |
| `Super + D` | Lanceur d'applications (Wofi) | `Super + F` | Plein écran |
| `Super + B` | Firefox | `Super + V` | Fenêtre flottante |
| `Super + G` | Steam | `Super + P` / `Super + J` | Pseudo-tiling / split |
| `Super + N` | Paramètres réseau | `Super + M` | Quitter Hyprland |
| `Super + 1…9` | Changer de bureau | `Super + Shift + 1…9` | Déplacer la fenêtre vers un bureau |

## Ce que contient cette version expérimentale

- Environnement live Arch Linux construit avec le profil officiel `archiso` (releng).
- Hyprland, Waybar, Wofi, Kitty, Dunst, NetworkManager et PipeWire/WirePlumber.
- Steam, Lutris, Firefox et les usuelles Mesa/Vulkan.
- Une première session graphique en tant qu'utilisateur non privilégié `prime`.
- Le wizard Faravahar pour Windows, Linux et macOS.

**Non encore implémenté :** installateur de disque, support Secure Boot, flux de mise à jour/récupération, optimisation matérielle automatique, et profils de jeu testés. Une ISO ne peut pas inclure tous les pilotes propriétaires ; le support NVIDIA dépend du modèle de la carte.

## Intégrité et sécurité

- Le module artistique `you.py` est récupéré via HTTPS, vérifié contre une SHA-256 épinglée, et uniquement **parsé**, jamais exécuté par l'application de configuration.
- Le logo est limité en taille et en pixels avant le décodage, et vérifié contre une SHA-256 épinglée.
- Les URL de téléchargement des releases doivent être HTTPS et pointer vers le chemin `releases/download` de ce dépôt.
- Les téléchargements atterrissent dans un fichier `.part` et sont déplacés seulement après la taille — et la checksum publiée, lorsqu'elle est disponible — correspondre.
- Les scripts vérifient la SHA-256 de chaque fichier qu'ils installent.
- Les hashs publiés sont épinglés dans `install.sh`, `install.ps1` et `loader.py` ; ils doivent être mis à jour ensemble whenever ces fichiers changent.

Vérifiez vous-même une image téléchargée :

```bash
sha256sum os.iso          # comparez avec les notes de release ou l'actif checksum
```

Déclarez un mismatch au lieu de bouder l'image.

## Construire l'ISO (développeurs seulement)

La construction est optionnelle et seulement nécessaire si vous voulez modifier l'image elle-même. Elle nécessite Docker et plusieurs gigaoctets d'espace libre.

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
docker run --rm --privileged \\
  -e PRIME_OS_BUILD_CONTAINER=1 \\
  -v \"$PWD:/work\" -w /work archlinux:latest \\
  bash -lc 'pacman -Syu --noconfirm archiso && bash ./build.sh'
```

`build.sh` refuse de s'exécuter en dehors d'un conteneur Arch explicitement marqué, copie le profil releng officiel dans `.build/profile`, active le dépôt `multilib` pour Steam **uniquement dans ce profil temporaire**, fusionne `components/`, et écrit le résultat dans `out/os.iso`.

Windows ne peut pas construire une ISO Arch directement — utilisez WSL2 avec une distribution Arch, ou `build.ps1` avec Docker Desktop.

### Construction en CI (GitHub Actions, sans build local)

1. Ouvrez **Actions → Build and publish ISO → Run workflow**.
2. Entrez un tag de release (par défaut `os-preview`) — la release est créée si elle n'existe pas.
3. Le travail s'exécute dans un conteneur Docker avec accès privileged, affiche **une barre de progression**, puis télécharge `os.iso` et `os.iso.sha256` vers cette release. Le journal complet reste un artifact.

Pousser un tag `v*` fait la même chose. Rien n'a à être construit sur votre propre machine ; une Codespace fonctionne pour un test interactif avec la même commande Docker, et le wrapper de progression fonctionne également là-bas.

## Structure du dépôt

| Chemin | Usage |
| --- | --- |
| `loader.py` | Application de configuration : lookup release, téléchargement ISO, artwork progressif, profil |
| `install.sh` / `install.ps1` | Bootstrap en une commande pour Linux/macOS et Windows |
| `you.py` | Rendeur vectoriel Faravahar (fournit en données, parsé mais pas exécuté) |
| `faravahar.png` | Logo utilisé par l'application de configuration et la session live |
| `components/*.list` | Una lista per componente (base, desktop, drivers-nvidia, …); `build.sh` unisce solo i gruppi scelti |
| `profile/airootfs/` | Fichiers dans l'image live (Hyprland, Waybar, autologin, setup) |
| `build.sh` / `build.ps1` | Construction ISO reproductible dans Docker |
| `run-windows.sh` | Boot l'ISO construite dans QEMU depuis Git Bash |
| `web_search.py` | Helper de recherche web Exa pour contributeurs et agents (`EXA_API_KEY`) |
| `.env.example` | Variables d'environnement placeholder ; copiez-le en `.env` (git-ignoré) |
| `requirements.txt` | Dépendances Python (`Pillow`, `exa-py`) pour l'application de configuration et helper de recherche |
| `NOTICE.md` | Ce que le projet est et n'est pas : licensing, marques déposées, sécurité, statut |
| `.github/` | Workflow qui construit l'ISO et le publie vers releases |

La session live démarre une fois, sur `tty1`, via le drop-in `getty` autologin plus `/etc/skel/.bash_profile` ; `prime-os-setup` crée l'utilisateur sans privilège `prime` et installe le `/etc/prime-os/hyprland.conf` canonical.

## Statut du projet

C'est un point de départ, pas un OS de jeu fini. Les prochaines milestones : valider la première image publiée sur du matériel réel, corriger les problèmes de démarrage et de paquets, concevoir un installateur, puis ajouter des profils de jeu testés plus des flux de mise à jour et de récupération. Les rapports de test matériel et les contributions sont les bienvenus — voir [CONTRIBUTING](#contributing).

## Licence

Publié sous la [Licence MIT](LICENSE) — libre d'utiliser, modifier et redistribuer, sans garantie.

Les performances de jeu et la compatibilité matérielle dépendent de votre GPU, de vos pilotes, du jeu et de votre matériel.

Elles ne peuvent pas être garanties.