# Prime-OS

[English](README.md) · [Français]· [العربية](README.ar.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [Farsi](README.fa.md)

> [!CAUTION]
> **Lisez [NOTICE.md](NOTICE.md) avant de télécharger, construire, miroité ou redistribuer quoi que ce soit.** Prime-OS est un prototype non fini et non affilié : aucune logiciel ou pilote propriétaire n'est redistribué, rien n'est garanti, et un mauvais choix de lecteur ou un mauvais usage des outils peut détruire des données.

**Prime-OS** est un projet communautaire construisant un système d'exploitation de jeu basé sur **Arch Linux** et le compositeur Wayland **Hyprland**. La milestone actuelle est une **ISO live bootable** — pas un installateur complet et pas un système d'exploitation prêt pour la production.

> [!IMPORTANT]
> Aucune partie de ce dépôt ne remplace votre système d'exploitation. L'application de configuration télécharge une image live et enregistre un fichier de préférences ; elle ne partitionne pas un disque, n'écrit pas sur une clé USB et n'installe pas Prime-OS. Testez d'abord l'image dans une machine virtuelle, et utilisez une clé USB de rechange si vous testez sur un matériel réel.

## Démarrage rapide

Vous n'avez **pas besoin** de Linux, Docker ou aucune étape de build. Le wizard de configuration télécharge l'`os.iso` publié dans la dernière Release GitHub et remplit l'artwork Faravahar avec la progression de téléchargement réelle : un pourcentage téléchargé est un pourcentage du dessin.

### Windows

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/bcfda5806544b362ac89c6986cb44ec78e48f748/install.ps1 | iex
```

> [!TIP]
> **Si la commande Windows échoue avec une erreur réseau** (`Unable to connect to the remote
> server`, `Could not connect to server` ou un délai dépassé), le problème vient de la connexion à
> GitHub, pas du script : **activez un VPN puis relancez la même commande**. Si un VPN est déjà
> actif et que l'échec persiste, **désactivez le VPN** (ou changez de serveur) et réessayez —
> certains VPN, filtres DNS et réseaux d'entreprise bloquent `raw.githubusercontent.com` et
> `github.com`. Vérifiez ensuite que `https://github.com` s'ouvre dans le navigateur, puis relancez
> la commande.

### Linux et macOS

```bash
curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh | bash
```
## Source de téléchargement

Prime-OS n'a qu'**une** source officielle : les **releases GitHub** du projet. Aucun miroir ni tiers,
donc une image ne peut venir que du dépôt qui publie son SHA-256. **Entrée** lance, **Échap** quitte.

## Dépannage

Voir la [référence des erreurs dans DOCS.md](DOCS.md) : chaque panne connue, sa cause et son correctif.

**Prérequis :** **Python 3 avec Tk**, **curl**, une connexion Internet, et assez d'espace libre pour l'image. Pillow est installé automatiquement dans un environnement virtuel privé.

Le wizard effectue ces actions :

1. Vérifie la dernière Release GitHub pour `os.iso` ;
2. Le télécharge dans le dossier de l'application avec une barre de progression en direct ;
3. Vérifie la taille, et la SHA-256 publiée lorsque le release inclut un fichier de checksum ;
4. Enregistre votre profil matériel.

Si aucune release n'a été publiée encore, le wizard le dit simplement et enregistre seulement le profil — il n'essaie pas de faire semblant d'installer un OS.

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

- Le module artistique `you.py` est récupéré via HTTPS, vérifié contre une SHA-256 épinglée, et uniquement **parsé**, jamais exécuté par le wizard.
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

`build.sh` refuse de s'exécuter en dehors d'un conteneur Arch explicitement marqué, copie le profil releng officiel dans `.build/profile`, active le dépôt `multilib` pour Steam **uniquement dans ce profil temporaire**, fusionne `profile/packages/`, et écrit le résultat dans `out/os.iso`.

Windows ne peut pas construire une ISO Arch directement — utilisez WSL2 avec une distribution Arch, ou `build.ps1` avec Docker Desktop.

### Construction en CI (GitHub Actions, sans build local)

1. Ouvrez **Actions → Build and publish ISO → Run workflow**.
2. Entrez un tag de release (par défaut `os-preview`) — la release est créée si elle n'existe pas.
3. Le travail s'exécute dans un conteneur Docker avec accès privileged, affiche **une barre de progression**, puis télécharge `os.iso` et `os.iso.sha256` vers cette release. Le journal complet reste un artifact.

Pousser un tag `v*` fait la même chose. Rien n'a à être construit sur votre propre machine ; une Codespace fonctionne pour un test interactif avec la même commande Docker, et le wrapper de progression fonctionne également là-bas.

## Structure du dépôt

| Chemin | Usage |
| --- | --- |
| `loader.py` | Wizard de configuration : lookup release, téléchargement ISO, artwork progressif, profil |
| `install.sh` / `install.ps1` | Bootstrap en une commande pour Linux/macOS et Windows |
| `you.py` | Rendeur vectoriel Faravahar (fournit en données, parsé mais pas exécuté) |
| `faravahar.png` | Logo utilisé par le wizard et la session live |
| `profile/packages/*.list` | Une liste par composant (base, desktop, drivers-nvidia, …) ; `build.sh` ne fusionne que les groupes choisis |
| `profile/airootfs/` | Fichiers dans l'image live (Hyprland, Waybar, autologin, setup) |
| `build.sh` / `build.ps1` | Construction ISO reproductible dans Docker |
| `run-windows.sh` | Boot l'ISO construite dans QEMU depuis Git Bash |
| `web_search.py` | Helper de recherche web Exa pour contributeurs et agents (`EXA_API_KEY`) |
| `.env.example` | Variables d'environnement placeholder ; copiez-le en `.env` (git-ignoré) |
| `requirements.txt` | Dépendances Python (`Pillow`, `exa-py`) pour le wizard et helper de recherche |
| `NOTICE.md` | Ce que le projet est et n'est pas : licensing, marques déposées, sécurité, statut |
| `.github/` | Workflow qui construit l'ISO et le publie vers releases |

La session live démarre une fois, sur `tty1`, via le drop-in `getty` autologin plus `/etc/skel/.bash_profile` ; `prime-os-live-setup` crée l'utilisateur sans privilège `prime` et installe le `/etc/prime-os/hyprland.conf` canonical.

## Statut du projet

C'est un point de départ, pas un OS de jeu fini. Les prochaines milestones : valider la première image publiée sur du matériel réel, corriger les problèmes de démarrage et de paquets, concevoir un installateur, puis ajouter des profils de jeu testés plus des flux de mise à jour et de récupération. Les rapports de test matériel et les contributions sont les bienvenus — voir [CONTRIBUTING](#contributing).

## Licence

Publié sous la [Licence MIT](LICENSE) — libre d'utiliser, modifier et redistribuer, sans garantie.

Les performances de jeu et la compatibilité matérielle dépendent de votre GPU, de vos pilotes, du jeu et de votre matériel.

Elles ne peuvent pas être garanties.