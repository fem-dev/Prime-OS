# Prime-OS

**یک نصب‌کنندهٔ کوچک و بوت‌شدنی که می‌پرسد چه می‌خواهی، و فقط همان را نصب می‌کند.**

Prime-OS یک سیستم بر پایهٔ Arch Linux و Hyprland است که یک قاعده دارد: فایلی که
دانلود می‌کنی **نصب‌کننده** است، نه یک دسکتاپ آماده. حجمش چند صد مگابایت است،
هیچ برنامه‌ای داخلش نیست، و وقتی بالا می‌آید می‌پرسد کدام بخش‌ها را می‌خواهی.
بقیه در همان لحظهٔ نصب، تک‌تک و فقط همان بخش‌هایی که انتخاب کردی، از مخازن Arch
گرفته می‌شود.

هیچ فایل عکسی در پروژه نیست: نه کاغذدیواری، نه لوگوی تصویری. نشست با رنگ‌های
ساده و تعریف‌شده در [`branding/palette.json`](branding/palette.json) خودش را
می‌کشد.

---

## چطور کار می‌کند

۱. **ایمیج را بوت کن.** کنسول اول به‌صورت خودکار با root وارد می‌شود و برنامهٔ
نصب را اجرا می‌کند؛ بقیهٔ کنسول‌ها یک شل معمولی می‌مانند.
۲. **سخت‌افزار و شبکه را بررسی می‌کند** و اگر به مخازن Arch نرسد، صریح می‌گوید.
۳. **دیسک را انتخاب می‌کنی.** همیشه باید کلمهٔ `ERASE` را تایپ کنی و روی دیسکی
که پارتیشن mount‌شده دارد دست نمی‌زند.
۴. **بخش‌ها را تیک می‌زنی**: دسکتاپ، درایور گرافیک، فونت‌ها، برنامه‌ها. هر بخش
یک فایل جداست؛ چیزی که تیک نزنی نصب نمی‌شود و قبل از تأیید، حجم دانلود را
می‌بینی.
۵. **نصب می‌کند**: `pacstrap` فقط پکیج‌های بخش‌های انتخاب‌شده را می‌نویسد، بعد
overlay نشست Prime-OS را روی سیستم جدید می‌گذارد، بوت‌لودر نصب می‌شود و حساب
کاربر ساخته می‌شود.
۶. **ری‌استارت.** روی ماشین نصب‌شده همان چیزی هست که انتخاب کردی، و نه بیشتر.

چیزی که ایمیج **عمداً** ندارد: دسکتاپ، برنامه، درایور، یا کپی کامل سیستم. کل
ایده همین است — چهل بخش که کاربر انتخاب می‌کند، بهتر از یک ایمیج ۲.۴ گیگی که
حدس می‌زند.

## بخش‌ها

هر بخش یک فایل در [`components/`](components): یک `.list` از نام پکیج‌های Arch و
یک `.desc` با عنوان و یک جمله توضیح. برای اضافه‌کردن بخش تازه، فقط همین دو فایل
را اضافه کن؛ هیچ کدی عوض نمی‌شود.

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

## نصب

یک خط، از داخل یک نشست زندهٔ Arch — [ایمیج رسمی Arch](https://archlinux.org/download/)
یا ایمیج نصب Prime-OS که پایین‌تر آمده:

```bash
curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh | sudo bash
```

ماشین را بررسی می‌کند، چند ابزاری که ویزارد لازم دارد را نصب می‌کند، همین مخزن را
می‌گیرد و ویزارد را اجرا می‌کند. بعد از آن همه‌چیز یک پرسش است: دیسک (باید `ERASE`
را تایپ کنی)، بخش‌ها، حساب کاربری. اگر همین دستور را روی ایمیج نصب Prime-OS اجرا
کنی، از نسخه‌ای که روی خود ایمیج هست استفاده می‌کند و چیزی دانلود نمی‌کند.

```bash
PRIME_OS_REF=6283bbebd95448b7957a19367f864ff1b6641f54 \
  curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/setup.sh | sudo -E bash
```

`PRIME_OS_REF` هر برنچ، تگ یا کامیتی را می‌پذیرد؛ پیش‌فرض `main` است. نصب‌کننده
بیرون از نشست زنده اجرا نمی‌شود، پس دیسک یک سیستم کاری به‌اشتباه پاک نمی‌شود.

### یا بوت کردن ایمیج نصب

`os.iso` را از [آخرین نسخه](https://github.com/fem-dev/Prime-OS/releases) بگیر،
با `sha256` منتشرشده بسنج، روی فلش بنویس و بوت کن:

```bash
sha256sum -c os.iso.sha256
sudo dd if=os.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

روی ویندوز، [Rufus](https://rufus.ie) یا [balenaEtcher](https://etcher.balancer.io)
همان فایل را می‌نویسند. ایمیج حالا آن‌قدر کوچک است که یک دانلود کافی باشد؛
manifest تکه‌ای نسخه‌های قبلی را ویزارد هنوز می‌فهمد.

### ویزارد (اختیاری)

یک برنامهٔ کوچک هم هست که ایمیج را دانلود و بررسی می‌کند. این برنامه هیچ‌وقت روی
فلش نمی‌نویسد و هیچ دیسکی را پارتیشن نمی‌کند.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

به Python 3 با Tk و `curl` نیاز دارد. اگر پنجره باز نشد، فایل را دستی دانلود کن؛
این مسیر فقط به مرورگر نیاز دارد.

## ساختن ایمیج

بیلد به `archiso` و root نیاز دارد، پس در کانتینر اجرا می‌شود:

```bash
docker run --rm -it --privileged -e PRIME_OS_BUILD_CONTAINER=1 \
  -v "$PWD:/work" -w /work archlinux:latest
# داخل کانتینر:
pacman -Syu --noconfirm archiso
bash build.sh
```

`out/os.iso` همان نصب‌کننده است. GitHub Actions با هر push روی `main` آن را
می‌سازد و منتشر می‌کند ([`.github/workflows/build-iso.yml`](.github/workflows/build-iso.yml)).

## ساختار مخزن

| مسیر | چیست |
| --- | --- |
| [`installer/prime-os-setup`](installer/prime-os-setup) | برنامه‌ای که روی ایمیج نصب اجرا می‌شود. |
| [`installer/lib/`](installer/lib) | یک فایل برای هر گام: `common`، `network`، `disk`، `components`، `account`، `apply`، `boot`. |
| [`installer/overlay/`](installer/overlay) | چیزی که روی سیستم **نصب‌شده** نوشته می‌شود: Hyprland، waybar، `issue`، `motd`، فهرست کلیدها. |
| [`components/`](components) | فهرست پکیج هر بخش که کاربر از میانشان انتخاب می‌کند. |
| [`profile/`](profile) | بخش زندهٔ ایمیج: `live-packages.list`، ورود خودکار، متن کنسول. |
| [`build.sh`](build.sh) | ایمیج را با `mkarchiso` می‌سازد. |
| [`loader.py`](loader.py) | دانلودر اختیاری دسکتاپ برای ایمیج. |
| [`setup.sh`](setup.sh) | نصب‌کنندهٔ یک‌خطی: مخزن را می‌گیرد و ویزارد را اجرا می‌کند. |
| [`install.sh`](install.sh)، [`install-mac.sh`](install-mac.sh)، [`install.ps1`](install.ps1) | نصب دانلودر، قفل‌شده به یک کامیت. |
| [`branding/`](branding) | پالت و قواعد نوشتاری برند. بدون فایل تصویری. |
| [`DOCS.md`](DOCS.md) | هر خطای شناخته‌شده، علتش و راه‌حلش. |

## روی سیستم نصب‌شده

| مسیر | چیست |
| --- | --- |
| `~/.config/hypr/hyprland.conf` | نشست: کلیدها، حاشیه‌ها، رنگ‌ها. |
| `~/.config/waybar/` | نوار. |
| `/etc/prime-os/install.conf` | این ماشین با چه چیزی نصب شده: بخش‌ها، دیسک، فایل‌سیستم، تاریخ. |
| `/usr/share/prime-os/keys.txt` | فهرست کلیدها، روی دیسک، تا `Super+/` بدون شبکه هم کار کند. |

`Super+Enter` ترمینال، `Super+D` لانچر، `Super+/` همان فهرست کلیدها. ورود root
روی سیستم نصب‌شده قفل است؛ حسابی که در نصب ساخته می‌شود در گروه `wheel` است و
از `sudo` استفاده می‌کند.

## وضعیت، صادقانه

- ایمیج یک **نصب‌کننده** است. هنوز نصب روی سخت‌افزار واقعی با کاربران زیاد
  آزمایش نشده؛ اولین نصب را آزمایشی بدان و پشتیبان داشته باش.
- سیستم نصب‌شده **ابزار به‌روزرسانی ندارد**: Arch خالص است، پس راه به‌روزرسانی
  `pacman -Syu` است.
- Secure Boot تنظیم نشده.
- به‌جز بیلد، چیزی خودکار تست نمی‌شود: ویزارد تست ندارد و CI فقط بررسی می‌کند
  ایمیج ساخته شده و اندازه‌اش درست است.

مجوز: MIT. برای اینکه این پروژه چه چیزی **نیست**، [`NOTICE.md`](NOTICE.md) را بخوان.
