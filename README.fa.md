# Prime-OS

یک نصب‌کنندهٔ کوچک و بوت‌شدنی برای یک دسکتاپ Arch Linux + Hyprland. فایلی که
دانلود می‌کنی **نصب‌کننده** است، نه دسکتاپ: می‌پرسد چه بخش‌هایی را می‌خواهی، فقط
همان‌ها را نصب می‌کند و بقیه را در همان لحظه از مخازن Arch می‌گیرد. هیچ فایل
عکسی در پروژه نیست — نشست رنگ‌هایش را از
[`branding/palette.json`](branding/palette.json) می‌گیرد.

---

## نصب

برچسب بالای هر بلوک را بخوان: سه راه مال سه سیستم‌عامل متفاوت است و با هم قابل
تعویض نیستند.

| ماشینت | نتیجه | راه |
| --- | --- | --- |
| **لینوکس**، از یک نشست زندهٔ Arch | Prime-OS روی همین کامپیوتر نصب می‌شود | [۱](#۱-همین-حالا-نصب-کن--فقط-لینوکس) |
| **لینوکس، مک، ویندوز** | یک فلش که Prime-OS را نصب می‌کند | [۲](#۲-نوشتن-روی-فلش--هر-سیستمعاملی) |
| **لینوکس، مک، ویندوز** | فقط فایل ایمیج، دانلودشده در یک پنجره | [۳](#۳-فقط-دانلود-ایمیج--هر-سیستمعاملی-اختیاری) |

### ۱. همین حالا نصب کن — فقط لینوکس

[ایمیج رسمی Arch](https://archlinux.org/download/) یا یک فلش Prime-OS را بوت کن.
اگر وای‌فای می‌خواهی، اول در کنسول زنده `nmtui` را بزن. بعد این دستور:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh)"
```

- نشست زنده خودش root است؛ از حساب معمولی، `sudo` را اولِ کل خط بگذار.
- شکل دستور را عوض نکن. `curl … | bash` کار نمی‌کند: لوله کنسول را با متن
  اسکریپت عوض می‌کند و ویزارد به کیبورد کنسول نیاز دارد. همان را می‌گوید و
  می‌ایستد.
- هر برنچ، تگ یا کامیت دیگری به‌جای `main`:

```bash
PRIME_OS_REF=main bash -c "$(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh)"
```

روی سیستم نصب‌شده اجرا نمی‌شود، پس دیسک ماشین کاری‌ات در امان است. این راه روی
ویندوز و مک وجود ندارد: نه نشست زندهٔ Arch هست نه `pacman`.

### ۲. نوشتن روی فلش — هر سیستم‌عاملی

**لینوکس**

```bash
cd ~/Downloads
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso.sha256
sha256sum -c os.iso.sha256
lsblk                       # فلش را پیدا کن، مثلاً /dev/sdb — دو بار چک کن
sudo dd if=os.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**مک**

```bash
cd ~/Downloads
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso
curl -fLO https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso.sha256
shasum -a 256 -c os.iso.sha256
diskutil list               # فلش را پیدا کن، مثلاً disk4
diskutil unmountDisk /dev/disk4
sudo dd if=os.iso of=/dev/rdisk4 bs=4m
```

**ویندوز** — PowerShell، بدون دسترسی administrator:

```powershell
cd $HOME\Downloads
irm https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso -OutFile os.iso
irm https://github.com/fem-dev/Prime-OS/releases/latest/download/os.iso.sha256 -OutFile os.iso.sha256
(Get-FileHash .\os.iso -Algorithm SHA256).Hash
Get-Content .\os.iso.sha256
```

دو هش باید یکی باشند. نوشتن روی فلش تنها گامی است که دستور ندارد:
[Rufus](https://rufus.ie) یا [balenaEtcher](https://etcher.balancer.io) را باز کن،
`os.iso` را انتخاب کن، و اگر Rufus دربارهٔ حالت ISOHybrid پرسید **DD image mode**
را بزن.

بعد ماشین را از فلش بوت کن (منوی بوت فریم‌ور: معمولاً `F12`، `F11` یا `Esc` هنگام
روشن‌شدن)؛ نصب‌کننده روی کنسول اول شروع می‌شود.

### ۳. فقط دانلود ایمیج — هر سیستم‌عاملی، اختیاری

یک پنجره که `os.iso` را دانلود می‌کند، SHA-256اش را بررسی می‌کند و ذخیره می‌کند.
روی فلش نمی‌نویسد و چیزی نصب نمی‌کند: نوشتن فلش کار راه ۲ است.

**لینوکس** — به `curl`، `python3`، `venv` و Tk نیاز دارد:

```bash
sudo apt install curl python3 python3-venv python3-tk   # دبیان، اوبونتو
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

**مک** — فایل `install-mac.sh` است، نه `install.sh` که به `sha256sum` نیاز دارد.
به Python 3 از python.org نیاز دارد (Tk همراه خودش است):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install-mac.sh)
```

**ویندوز** — PowerShell 5.1 یا جدیدتر، Python 3 از python.org با گزینه‌های
*Add python.exe to PATH* و *tcl/tk and IDLE*:

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

اگر گامی شکست بخورد دلیلش را می‌گوید و لاگ می‌گذارد: روی ویندوز در
`%TEMP%\prime-os-install.log`، جای دیگر روی همان صفحه. اگر پنجره باز نشد، از راه ۲
استفاده کن؛ آن راه جز `curl` یا یک مرورگر چیزی نمی‌خواهد.

## نصب‌کننده چه می‌پرسد

۱. **دیسک.** باید `ERASE` را تایپ کنی، و روی دیسکی که پارتیشن mount‌شده دارد دست
نمی‌زند.
۲. **بخش‌ها.** هر بخش یک فایل در [`components/`](components) است: یک `.list` از
پکیج‌های Arch و یک `.desc`. تیک‌نزده نصب نمی‌شود و حجم دانلود قبل از تأیید
نشان داده می‌شود.
۳. **حساب کاربری.** بعد `pacstrap` پکیج‌های انتخاب‌شده را می‌نویسد، overlay نشست
Prime-OS را روی سیستم جدید می‌گذارد، بوت‌لودر نصب می‌شود و بعد از ری‌استارت همان
چیزی را داری که انتخاب کردی.

## بخش‌ها

| بخش | فایل | چه نصب می‌کند |
| --- | --- | --- |
| سیستم پایه | [`base.list`](components/base.list) | کرنل، pacman، NetworkManager، sudo. همیشه نصب می‌شود. |
| دسکتاپ Hyprland | [`desktop.list`](components/desktop.list) | Hyprland، waybar، wofi، portalها، PipeWire، kitty، dunst. |
| برنامه‌های روزمره | [`apps.list`](components/apps.list) | Firefox، Geany. |
| فونت لاتین و ایموجی | [`fonts.list`](components/fonts.list) | Noto و فونت ایموجی. |
| فونت چینی/ژاپنی/کره‌ای | [`fonts-cjk.list`](components/fonts-cjk.list) | Noto CJK، حدود ۱۹۰ مگابایت. |
| گرافیک AMD | [`drivers-amd.list`](components/drivers-amd.list) | Mesa، Vulkan، رمزگشایی ویدیو. |
| گرافیک Intel | [`drivers-intel.list`](components/drivers-intel.list) | Mesa، Vulkan، درایور رسانه. |
| NVIDIA (اختصاصی) | [`drivers-nvidia.list`](components/drivers-nvidia.list) | `nvidia-open` و ابزارش. حجیم. |
| کتابخانه‌های ۳۲بیتی بازی | [`gaming-32bit.list`](components/gaming-32bit.list) | lib32 Mesa/Vulkan/صدا و فعال‌سازی multilib. |

برای اضافه‌کردن بخش تازه فقط همین دو فایل را اضافه کن — هیچ کدی عوض نمی‌شود.

## ساختن ایمیج — لینوکس با داکر

`archiso` به root نیاز دارد، پس بیلد در کانتینر اجرا می‌شود:

```bash
docker run --rm -it --privileged -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest
# داخل کانتینر:
pacman -Syu --noconfirm archiso
bash build.sh
```

`out/os.iso` همان نصب‌کننده است. GitHub Actions با هر push روی `main` می‌سازدش و
منتشر می‌کند ([`build-iso.yml`](.github/workflows/build-iso.yml))، پس برای گرفتن
ایمیج لازم نیست خودت بیلد کنی.

## فایل‌ها

| مسیر | چیست |
| --- | --- |
| [`installer/prime-os-setup`](installer/prime-os-setup) | برنامه‌ای که روی ایمیج نصب اجرا می‌شود. |
| [`installer/lib/`](installer/lib) | یک فایل برای هر گام: `common`، `network`، `disk`، `components`، `account`، `apply`، `boot`. |
| [`installer/overlay/`](installer/overlay) | چیزی که روی سیستم نصب‌شده نوشته می‌شود: Hyprland، waybar، `issue`، `motd`، فهرست کلیدها. |
| [`components/`](components) | فهرست پکیج هر بخش که کاربر انتخاب می‌کند. |
| [`profile/`](profile) | بخش زندهٔ ایمیج: `live-packages.list`، ورود خودکار، متن کنسول. |
| [`build.sh`](build.sh) | ایمیج را با `mkarchiso` می‌سازد. |
| [`setup.sh`](setup.sh) | راه ۱: مخزن را می‌گیرد و ویزارد را اجرا می‌کند. |
| [`install.sh`](install.sh) · [`install-mac.sh`](install-mac.sh) · [`install.ps1`](install.ps1) | راه ۳: دانلودر، یکی برای هر سیستم‌عامل، قفل‌شده به یک کامیت. |
| [`loader.py`](loader.py) | پنجرهٔ دانلودر که هر سه اسکریپت اجرا می‌کنند. |
| [`DOCS.md`](DOCS.md) | هر خطای شناخته‌شده، علتش و راه‌حلش. |

## روی سیستم نصب‌شده

`Super+Enter` ترمینال، `Super+D` لانچر، `Super+/` فهرست کلیدها. ورود root قفل است؛
حسابِ ساخته‌شده در نصب در گروه `wheel` است و از `sudo` استفاده می‌کند. تنظیمات در
`~/.config/hypr/` و `~/.config/waybar/` است و سابقهٔ نصب در
`/etc/prime-os/install.conf`.

## وضعیت، صادقانه

- ایمیج یک **نصب‌کننده** است. هنوز نصب گسترده روی سخت‌افزار واقعی انجام نشده؛
  اولین نصب را آزمایشی بدان و پشتیبان داشته باش.
- سیستم نصب‌شده Arch خالص است: با `pacman -Syu` به‌روزش کن. ابزار به‌روزرسانی
  ندارد و Secure Boot تنظیم نشده.
- به‌جز بیلد چیزی خودکار تست نمی‌شود؛ CI فقط بررسی می‌کند ایمیج ساخته شده و
  اندازه‌اش درست است.
- فقط همین فایل و [`README.md`](README.md) به‌روزند. بقیهٔ ترجمه‌ها
  (`README.*.md`) نسخهٔ قدیمی‌تر را توصیف می‌کنند و عقب می‌مانند.

مجوز: MIT. برای اینکه این پروژه چه چیزی **نیست**، [`NOTICE.md`](NOTICE.md) را بخوان.
