# Prime-OS

> **Note:** this translation predates the setup-installer layout. The commands still work; the structure sections describe an older image. [README.md](README.md) is the reference.


[English](README.md) · [中文]· [العربية](README.ar.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [Farsi](README.fa.md) · [Français](README.fr.md) · [Italiano](README.it.md) · [Português](README.po.md) · [Русский](README.ru.md)

> [!CAUTION]
> **请在下载、构建、镜像或重新分发任何内容之前阅读 [NOTICE.md](NOTICE.md)。** Prime-OS 是一个未完成且非官方的原型：不重新分发任何专有软件或驱动程序，没有任何保证，错误的磁盘选择或工具的错误用法可能会导致数据丢失。

**Prime-OS** 是一个基于 **Arch Linux** 和 Wayland 合成器 **Hyprland** 的社区构建游戏操作系统项目。当前里程碑是 **可启动的 live ISO**——不是完整的安装程序，也不是可生产使用的操作系统。

> [!IMPORTANT]
> 本仓库的任何部分都不替代您的操作系统。设置应用程序会下载一个 live 镜像并保存偏好设置；它不会分区磁盘、不写入 USB 驱动器，也不会安装 Prime-OS。先在虚拟机中测试镜像，在真实硬件测试时使用空闲的 USB 驱动器。

## 快速开始

**不需要 Linux、Docker 或任何构建步骤。** 设置 wizard 下载已发布的 `os.iso` 来自 GitHub 的最新 Release，并随实际下载进度填充 Faravahar 艺术：下载了百分之几就是画面的百分之几。

### Windows

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

> [!TIP]
> **如果 Windows 命令因网络错误失败**（`Unable to connect to the remote server`、
> `Could not connect to server` 或超时），问题出在到 GitHub 的连接，而不是脚本本身：
> **打开 VPN 后重新运行同一条命令**。如果已经开着 VPN 仍然失败，**请关闭 VPN**（或换一个服务器）
> 再试一次 —— 部分 VPN、DNS 过滤器和公司网络会封锁 `raw.githubusercontent.com` 和
> `github.com`。然后在浏览器中打开 `https://github.com` 确认连接正常，再运行一次同样的命令。

### Linux

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install-mac.sh)
```

## 下载源

Prime-OS 只有一个官方下载源：项目的 **GitHub releases**。没有镜像，也没有第三方主机，因此镜像文件
只能来自发布其 SHA-256 的那个仓库。**Enter** 开始，**Esc** 退出。

## 故障排查

请参阅 [DOCS.md 错误参考](DOCS.md)：每个已知故障、原因与解决方法。

**先决条件：** **Python 3 配合 Tk**，**curl**，互联网连接，以及足够的空间用于镜像。Pillow 会自动安装在私有的虚拟环境中。

设置 wizard 执行以下操作：

1. 检查 GitHub 最新 Release 中的 `os.iso`；
2. 带实时进度条下载到应用文件夹；
3. 验证大小，并在 Release 包含 checksum 文件时验证已发布的 SHA-256；
4. 保存您的硬件偏好设置。

如果还没有发布 Release， wizard 会明确说明这一点，并只保存偏好设置——它不会假装安装操作系统。

| | Windows | Linux / macOS |
| --- | --- | --- |
| 应用文件 | `%LOCALAPPDATA%\\Prime-OS` | `~/.local/share/prime-os` |
| 设置 | `%APPDATA%\\Prime-OS\\setup.json` | `~/.config/prime-os/setup.json` |

## 尝试 live 图像

将 `os.iso` 写入任何空闲的 USB 盘，或直接在 UEFI 虚拟机中启动。

```bash
# QEMU, 只读 CD-ROM，主机上不做任何修改
qemu-system-x86_64 -m 4G -smp 2 -cpu max -enable-kvm \\
  -drive file=os.iso,media=cdrom,readonly=on -boot d
```

在 Windows 下，`./run-windows.sh` 从 Git Bash 中用 QEMU 启动 `out/os.iso`。

### 键盘快捷键

| 快捷键 | 功能 | 快捷键 | 功能 |
| --- | --- | --- | --- |
| `Super + Enter` | Terminal (Kitty) | `Super + Q` | 关闭窗口 |
| `Super + D` | 应用启动器 (Wofi) | `Super + F` | 全屏 |
| `Super + B` | Firefox | `Super + V` | 浮动窗口 |
| `Super + G` | Steam | `Super + P` / `Super + J` | 伪平链 / 分割 |
| `Super + N` | 网络设置 | `Super + M` | 退出 Hyprland |
| `Super + 1…9` | 切换工作区 | `Super + Shift + 1…9` | 将窗口移动到工作区 |

## 该实验版包含的内容

- 由官方 `archiso` releng 配置文件构建的 Arch Linux live 环境。
- Hyprland, Waybar, Wofi, Kitty, Dunst, NetworkManager 和 PipeWire/WirePlumber。
- Steam, Lutris, Firefox 和常规 Mesa/Vulkan 用户空间驱动程序。
- 作为常规未特权 `prime` 用户的最小首次启动图形会话。
- Windows, Linux 和 macOS 的 Faravahar wizard.

**尚未实现：** 磁盘安装程序, Secure Boot 支持, 更新/恢复流程, 自动硬件调优, 以及测试过的游戏配置。单张 ISO 不能携带所有专有驱动程序；NVIDIA 支持取决于显卡型号。

## 完整性和安全性

- 艺术模块 `you.py` 通过 HTTPS 获取，与 pinned SHA-256 检查，仅 **parsing**，永不由 wizard 执行。
- 标志在解码前限制大小和像素数，并与 pinned SHA-256 检查。
- 下载 URL 必须是 HTTPS 并指向本仓库 `releases/download` 路径。
- 下载  atter在 `.part` 文件中，仅在大小 — 以及已发布的 checksum，如果有的话 — 匹配后才移动。
- 脚本检查他们安装的每个文件的 SHA-256。
- 已发布的 hashs 在 `install.sh`, `install.ps1` 和 `loader.py` 中固定；每次这些文件变更时必须一起更新。

自己验证下载的镜像：

```bash
sha256sum os.iso          # 与 Release 说明或 checksum 资产比较
```

不匹配时请勿启动镜像。

## 构建 ISO (仅限开发者)

构建是可选的，仅在您想要修改镜像本身时需要。需要 Docker 和数 GB 的空闲空间。

```bash
git clone https://github.com/fem-dev/Prime-OS.git
cd Prime-OS
docker run --rm --privileged \\
  -e PRIME_OS_BUILD_CONTAINER=1 \\
  -v \"$PWD:/work\" -w /work archlinux:latest \\
  bash -lc 'pacman -Syu --noconfirm archiso && bash ./build.sh'
```

`build.sh` 拒绝在明确标记的 Arch 容器外运行，将官方 releng 配置复制到 `.build/profile`，仅在该临时配置中启用 `multilib` repo 用于 Steam，合并 `components/`，并将结果写入 `out/os.iso`。

Windows 无法直接构建 Arch ISO — 使用 WSL2 配合 Arch distribution，或使用 `build.ps1` 配合 Docker Desktop.

### 在 CI 中构建 (GitHub Actions, 无本地构建)

1. 打开 **Actions → Build and publish ISO → Run workflow**。
2. 输入 Release 标签 (默认 `os-preview`) — 如果不存在则创建 Release。
3. 工作在具备 privileged 权限的 Docker 容器中运行，显示 **一个进度条**，随后下载 `os.iso` 和 `os.iso.sha256` 到该 Release。完整的日志保留为 artifact。

推送 `v*` 标签同样执行同样的操作。无需在您自己的机器上构建；Codespace 可用于与相同的 Docker 命令进行交互式测试，进度包装器也同样在那里工作。

## 仓库结构

| 路径 | 用途 |
| --- | --- |
| `loader.py` | 设置 wizard: release 查找, ISO 下载, 艺术进度, 配置文件 |
| `install.sh` / `install.ps1` | Linux/macOS 和 Windows 的一键启动 |
| `you.py` | Faravahar vector renderer (以数据形式提供, 被解析但不执行) |
| `faravahar.png` | wizard 和 live 会话使用的标志 |
| `components/*.list` | 每个组件一个列表（base、desktop、drivers-nvidia……），`build.sh` 只合并所选分组 |
| `profile/airootfs/` | live 镜像中的文件 (Hyprland, Waybar, autologin, setup) |
| `build.sh` / `build.ps1` | Docker 中的可重复 ISO 构建 |
| `run-windows.sh` | 从 Git Bash 中用 QEMU 启动 ISO |
| `web_search.py` | 具有 `EXA_API_KEY` 的 Contributors 和 agents 的 Exa web search helper |
| `.env.example` | 环境变量占位符; 复制为 `.env` (git-ignored) |
| `requirements.txt` | Python 依赖 (`Pillow`, `exa-py`) 用于设置 wizard 和 search helper |
| `NOTICE.md` | 项目包含和不包含的内容: 许可证, 商标, 安全, 状态 |
| `.github/` | 构建 ISO 并发布到 Release 的 Workflow |

Live 会话通过 `tty1` 的 `getty` autologin drop-in 加上 `/etc/skel/.bash_profile` 开始；`prime-os-setup` 创建无特权的 `prime` 用户并安装 canonical `/etc/prime-os/hyprland.conf`.

## 项目状态

这是一个起点，不是完成的游戏操作系统。下一个里程碑：在真实硬件上验证已发布的镜像，修复启动和包问题，设计安装程序，然后添加测试过的游戏配置 plus 更新和恢复流程。硬件测试报告和贡献受欢迎 — 参见 [CONTRIBUTING](#contributing).

## 许可证

根据 [MIT License](LICENSE) 发布 — 自由使用、修改和 redistribuire，无保证。

游戏性能和硬件兼容性取决于您的 GPU、驱动程序、游戏和硬件。

无法保证。