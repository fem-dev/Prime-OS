# Prime-OS

[English](README.md) · [Português]· [العربية](README.ar.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [Farsi](README.fa.md) · [Français](README.fr.md) · [Italiano](README.it.md)

> [!CAUTION]
> **Leia [NOTICE.md](NOTICE.md) antes de baixar, construir, especular ou redistribuir algo.** Prime-OS é um protótipo não finalizado e não afiliado: nenhum software ou driver proprietário é redistribuído, nada é garantido, e uma escolha errada de disco ou um uso indevido das ferramentas pode destruir dados.

**Prime-OS** é um projeto da comunidade construindo um sistema operacional de games baseado em **Arch Linux** e o compositor Wayland **Hyprland**. A milestone atual é uma **ISO live bootable** — não um instalador completo e não um sistema operacional pronto para produção.

> [!IMPORTANT]
> Nenhuma parte deste repositório substitui o seu sistema operativo. O aplicativo de configuração baixa uma imagem live e salva um arquivo de preferências; não particiona um disco, não escreve em um USB drive e não instala Prime-OS. Teste primeiro a imagem em uma máquina virtual, e use um drive USB de reserva se testar em hardware real.

## Início rápido

**Não é necessário Linux, Docker ou nenhum passo de build.** O wizard de configuração baixa o `os.iso` publicado na última Release GitHub e preenche o artwork Faravahar com a progressão de download real: um percentual download é um percentual do desenho.

### Windows

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/9d9e4850bc02ea14b5c97b1072e025f4dda01e5b/install.ps1 | iex
```

> [!TIP]
> **Se o comando no Windows falhar com erro de rede** (`Unable to connect to the remote server`,
> `Could not connect to server` ou tempo esgotado), o problema é a conexão com o GitHub, não o
> script: **ative uma VPN e execute o mesmo comando novamente**. Se já houver uma VPN ativa e
> ainda falhar, **desative a VPN** (ou troque de servidor) e tente de novo — algumas VPNs, filtros
> de DNS e redes corporativas bloqueiam `raw.githubusercontent.com` e `github.com`. Depois abra
> `https://github.com` no navegador para confirmar a conexão e execute o comando outra vez.

### Linux e macOS

```bash
curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh | bash
```
## Fonte de download

O Prime-OS tem exatamente **uma** fonte oficial: as **releases do GitHub** do projeto. Não há espelho
nem terceiros, então a imagem só pode vir do repositório que publica o seu SHA-256. **Enter** inicia
e **Esc** sai.

## Solução de problemas

Veja a [referência de erros em DOCS.md](DOCS.md): cada falha conhecida com causa e correção.

**Pré-requisitos:** **Python 3 com Tk**, **curl**, uma conexão Internet, e suficiente espaço livre para a imagem. Pillow é instalado automaticamente em um ambiente virtual privado.

O wizard realiza estas ações :

1. Verifica a última Release GitHub para `os.iso` ;
2. Baixa-a na pasta do aplicativo com uma barra de progressão em direto ;
3. Verifica o tamanho, e a SHA-256 publicada quando o release inclui um arquivo de checksum ;
4. Salva o seu perfil de hardware.

Se nenhuma release tiver sido publicada ainda, o wizard diz simplesmente e salva apenas o perfil — ele não tenta fingir installer um OS.

| | Windows | Linux / macOS |
| --- | --- | --- |
| Arquivos do app | `%LOCALAPPDATA%\\Prime-OS` | `~/.local/share/prime-os` |
| Preferências | `%APPDATA%\\Prime-OS\\setup.json` | `~/.config/prime-os/setup.json` |

## Experimentar a imagem live

Escreva `os.iso` em um drive USB vazio com qualquer ferramenta de escrita de imagem, ou inicie-a diretamente em uma máquina virtuelle UEFI.

```bash
# QEMU, CD-ROM em leitura-only, nada no host é modificado
qemu-system-x86_64 -m 4G -smp 2 -cpu max -enable-kvm \\
  -drive file=os.iso,media=cdrom,readonly=on -boot d
```

Under Windows, `./run-windows.sh` inicia `out/os.iso` desde Git Bash (QEMU requis).

### Atalhos de teclado

| Teclas | Action | Teclas | Action |
| --- | --- | --- | --- |
| `Super + Enter` | Terminal (Kitty) | `Super + Q` | Fechar janela |
| `Super + D` | Lançador de aplicações (Wofi) | `Super + F` | Tela cheia |
| `Super + B` | Firefox | `Super + V` | Janela flutuante |
| `Super + G` | Steam | `Super + P` / `Super + J` | Pseudo-tiling / split |
| `Super + N` | Configurações de rede | `Super + M` | Sair do Hyprland |
| `Super + 1…9` | Mudar de desktop | `Super + Shift + 1…9` | Mover janela para um desktop |

## O que esta versão experimental contém

- Ambiente live Arch Linux construído com o perfil oficial `archiso` (releng).
- Hyprland, Waybar, Wofi, Kitty, Dunst, NetworkManager e PipeWire/WirePlumber.
- Steam, Lutris, Firefox e as usuais Mesa/Vulkan.
- Uma primeira session gráfica como usuário não privilegiado `prime`.
- O wizard Faravahar para Windows, Linux e macOS.

**Não ainda implementado :** instaler de disco, suporte Secure Boot, fluxos de atualização e recuperação, otimização automática de hardware, e perfis de jogo testados. Uma ISO não pode incluir todos os drivers proprietários ; o suporte NVIDIA depende do modelo da placa.

## Integridade e segurança

- O módulo artístico `you.py` é recuperado via HTTPS, verificado contra uma SHA-256 pinned, e apenas **parsado**, nunca executado pelo wizard.
- O logo é limitado em tamanho e pixels avant le décodage, et vérifié contre une SHA-256 pinned.
- Les URLs de téléchargement des releases doivent être HTTPS et pointer vers le chemin `releases/download` deste dépôt.
- Les téléchargements atterrissent dans un fichier `.part` et sont déplacés seulement après la taille — et la checksum publiée, lorsqu'elle est disponible — correspondre.
- Les scripts vérifient la SHA-256 de chaque fichier qu'ils installent.
- Les hashs publiés sont épinglés dans `install.sh`, `install.ps1` et `loader.py` ; ils doivent être mis à jour ensemble whenever ces fichiers changent.

Vérifiez vous-même une image downloadée :

```bash
sha256sum os.iso          # comparez avec as notas de release ou o ativo checksum
```

Déclarez un mismatch au lieu de bootper a image.

## Construir a ISO (apenas desenvolvedores)

A construção est opciónnal et seulement nécessaire se vous voulez modifier l'image elle-même. Elle nécessite Docker e vários gigaoctets de espaço livre.

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
docker run --rm --privileged \\
  -e PRIME_OS_BUILD_CONTAINER=1 \\
  -v \"$PWD:/work\" -w /work archlinux:latest \\
  bash -lc 'pacman -Syu --noconfirm archiso && bash ./build.sh'
```

`build.sh` refuse de s'exécuter en dehors d'un conteneur Arch explicitement marcado, copie o perfil releng officiel dans `.build/profile`, active o repositório `multilib` pour Steam **uniquement neste perfil temporário**, fusiona `profile/packages.x86_64`, e escreve o resultado em `out/os.iso`.

Windows ne peut pas construire uma ISO Arch directly — utilisez WSL2 avec uma distribuição Arch, ou `build.ps1` avec Docker Desktop.

### Construção em CI (GitHub Actions, sem build local)

1. Abra **Actions → Build and publish ISO → Run workflow**.
2. Entre um tag de release (padrão `os-preview`) — a release é criada se ela n'existe pas.
3. O trabalho s'exécute num conteneur Docker com acesso privileged, affiche **uma barra de progressão**, poi télécharge `os.iso` e `os.iso.sha256` vers cette release. O journal complet reste um artifact.

Pousser um tag `v*` fait la même chose. Rien n'a a ser construit sur sua própria machine ; uma Codespace fonctionne pour um test interactif com a mesma commande Docker, et o wrapper de progressão fonctionne également là-bas.

## Estrutura do repositório

| Caminho | Uso |
| --- | --- |
| `loader.py` | Wizard de configuração : lookup release, téléchargement ISO, artwork progressif, perfil |
| `install.sh` / `install.ps1` | Bootstrap em uma comando para Linux/macOS e Windows |
| `you.py` | Rendeur vectoriel Faravahar (fournit en dados, parsé mas não executado) |
| `faravahar.png` | Logo usado pelo wizard e live session |
| `profile/packages.x86_64` | Pacotes adicionais fusionados no perfil ArchISO |
| `profile/airootfs/` | Fichiers dans l'image live (Hyprland, Waybar, autologin, setup) |
| `build.sh` / `build.ps1` | Construction ISO reproductível dans Docker |
| `run-windows.sh` | Boot l'ISO construite dans QEMU depuis Git Bash |
| `web_search.py` | Helper de recherche web Exa pour contributeurs et agents (`EXA_API_KEY`) |
| `.env.example` | Variáveis d'environnement placeholder ; copie-le em `.env` (git-ignorado) |
| `requirements.txt` | Dépendances Python (`Pillow`, `exa-py`) pour l'application de configuration et helper de recherche |
| `NOTICE.md` | O que o projeto é e n'est pas : licensing, marcas déposées, segurança, status |
| `.github/` | Workflow qui construit l'ISO e le publie vers releases |

A session live démarre une fois, sur `tty1`, via le drop-in `getty` autologin plus `/etc/skel/.bash_profile` ; `prime-os-live-setup` crée l'utilisateur sem privilégié `prime` e installe le `/etc/prime-os/hyprland.conf` canonical.

## Status do projeto

C'est um ponto de départ, pas um OS de jogo finito. Les prochaines milestones : valider la première image publiée sur du matériel réel, corriger les problèmes de démarrage et de paquets, concevoir un installateur, puis ajouter des profils de jeu testés plus des flux de mise à jour et de récupération. Les rapports de test matériel et les contributions sont les bienvenus — voir [CONTRIBUTING](#contributing).

## Licença

Publié sous la [Licence MIT](LICENSE) — livre d'utiliser, modifier et redistribuer, sans garantie.

Les performances de jeu et la compatibilité matérielle dépendem de votre GPU, de vos pilotes, du jeu et de votre matériel.

Elles não podem ser garantidas.