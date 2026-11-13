# NOTICE — read this first

[فارسی پایین‌تر است ↓](#اطلاعیه--اول-این-را-بخوانید)

> **Prime-OS is an unaffiliated, unfinished, volunteer prototype.**
> It is a community-built live Linux image for testing a Hyprland desktop, published for learning
> and experimentation. It is **not** a commercial product, **not** a supported operating system,
> **not** an official Arch Linux project, and **not** endorsed by any hardware vendor, game store or
> software publisher. Nothing here is guaranteed to work, and misuse can destroy data.

This document exists so that nobody — visitor, contributor, packager or platform reviewer — has to
guess what this repository is, what it ships, and what it deliberately does not ship. Please read it
before you download, build, mirror, redistribute or publish anything from this project.

---

## 1. What this project is

- A **build recipe** for a bootable Arch Linux live image with the Hyprland Wayland desktop, plus a
  small setup wizard written in Python that downloads that image.
- A **prototype**: the current milestone is "an image boots and shows a desktop". Disk installation,
  secure boot, updates, recovery and hardware tuning are **not implemented**.
- **Source-available and MIT licensed**: our scripts, configuration and artwork code may be used,
  modified, mirrored and redistributed under the terms in [LICENSE](LICENSE).
- **Reproducible from public packages**: the image is assembled by the official `archiso` tool from
  packages in the public Arch Linux repositories. We do not host, patch or relicense those packages.

## 2. What this project is not

- **Not affiliated with Arch Linux.** "Arch Linux" is a trademark of the Arch Linux project and its
  maintainers. Prime-OS merely uses their public packages and the official `archiso` profile.
- **Not affiliated with Hyprland, Waybar, Wofi, Kitty, Dunst, PipeWire, Firefox, Steam, Lutris,
  NVIDIA, AMD, Intel or any other upstream project.** Those names are used only to describe what the
  live image contains.
- **Not a distributor of proprietary software.** The image contains only packages that are public in
  the Arch Linux repositories at build time. Proprietary components (for example the Steam client or
  NVIDIA's driver packages) come from Arch's own repositories under **their own licences and terms**;
  this project does not bundle, crack, patch, mirror or relicense them, and does not grant you any
  right to use them. You are responsible for accepting those terms yourself.
- **Not a promise of performance.** No statement here means "runs every game", "no lag", "faster than
  Windows" or any other benchmark claim. We publish no performance numbers that we have not measured,
  and hardware results vary by GPU, driver, game and configuration.
- **Not a replacement for your operating system.** It does not install over anything, does not touch
  partitions by itself, and has no telemetry, no accounts, no licence keys and no paid tier.
- **Not a security boundary.** A live image with an autologin session is a testing environment, not a
  hardened system. Do not run it on a machine you do not control, and do not assume your data on a
  mounted disk is protected.

## 3. Safety and data loss

Booting a live image and writing it to a drive are genuinely destructive operations when done wrong.
The project therefore states, plainly:

1. **Test in a virtual machine first.** `qemu-system-x86_64` with a read-only CD-ROM changes nothing
   on your host.
2. **Never write the image to the drive that holds your data.** Writing an ISO to the wrong device
   erases it; that action is taken by you with your own tools, not by this repository.
3. **No warranty.** The software is provided "as is", without warranty of any kind, as stated in the
   MIT licence. If it breaks something, the authors are not liable.
4. **No support promise.** Issues and pull requests are answered on a best-effort, volunteer basis.

## 4. Integrity of what you download

- The setup wizard accepts release URLs only over **HTTPS** and only from this repository's
  `releases/download/` path.
- Downloads are written to a `.part` file, checked against `Content-Length`, and — when the release
  includes a checksum file — verified against a published **SHA-256** before they are moved into
  place. A mismatch deletes the file instead of booting it.
- Installed scripts are verified against **pinned SHA-256 hashes**; the installers fail closed.
- The artwork module `you.py` is fetched over HTTPS, hash-checked and only **parsed**, never executed.
- Release builds are produced by GitHub Actions from the source in this repository, so the published
  image can be traced back to a commit. The build log is kept as a workflow artifact.

If any of those checks fail on your machine, **do not boot the image**. Report it instead.

## 5. Third-party components and trademarks

| Component | Status in this project |
| --- | --- |
| Arch Linux packages | Installed from public mirrors at build time; their own licences apply |
| Steam client, NVIDIA drivers and other proprietary packages | From Arch's repositories; **not** redistributed by us; their terms apply |
| Hyprland, Waybar, Wofi, Kitty, Dunst, PipeWire | Separate upstream projects, each with its own licence |
| `faravahar.png`, `you.py` vector artwork | Part of this repository, released under the MIT licence |
| Names and logos of upstream projects | Trademarks of their owners; used descriptively only |

If you believe content in this repository infringes your rights, open an issue or contact the
maintainer of the GitHub repository; material will be removed or corrected promptly.

## 6. Contributing rules that keep the project honest

- Do not add marketing claims, benchmark numbers without measurements, or wording that implies an
  official relationship with Arch Linux, Valve, NVIDIA or any other company.
- Do not add proprietary binaries, keys, licence files, fonts or artwork you do not have the right to
  redistribute.
- Do not add telemetry, tracking, ads or any hidden network call that is not documented in the README.
- Keep the ISO buildable from public packages only, and keep the "preview" wording in the docs until
  an installer actually exists.

## 7. Status summary

| Area | State |
| --- | --- |
| Live image build | Works via GitHub Actions (buildable locally with Docker) |
| Download wizard (Windows/Linux/macOS) | Implemented; downloads and verifies the published image |
| Disk installer | **Not implemented** |
| Secure Boot / signed boot chain | **Not implemented** |
| Updates, recovery, rollback | **Not implemented** |
| Automatic hardware tuning | **Not implemented** (the wizard saves preferences only) |
| Tested hardware list | **None yet** — reports are welcome |

---

# اطلاعیه — اول این را بخوانید

> **پرایم‌اواس یک پروژهٔ داوطلبانهٔ ناتمام و مستقل است.**
> یک ایمیج زندهٔ لینوکس برای آزمایش میزکار Hyprland که فقط برای یادگیری و آزمون منتشر شده است.
> این پروژه **محصول تجاری نیست**، **سیستم‌عامل پشتیبانی‌شده نیست**، **پروژهٔ رسمی Arch Linux نیست** و
> **تأییدشده توسط هیچ سازندهٔ سخت‌افزار، فروشگاه بازی یا ناشر نرم‌افزاری نیست**. هیچ‌چیز در آن تضمین‌شده
> نیست و استفادهٔ نادرست می‌تواند داده‌ها را از بین ببرد.

این سند برای این نوشته شده که هیچ‌کس — بازدیدکننده، مشارکت‌کننده، بسته‌بند یا بازبین پلتفرم — مجبور
نباشد حدس بزند این مخزن چیست، چه چیزی منتشر می‌کند و چه چیزی را **عمداً** منتشر نمی‌کند. پیش از
دانلود، ساخت، آینه‌کردن، بازتوزیع یا انتشار هر چیزی از این پروژه آن را بخوانید.

### این پروژه چیست

- یک **دستور ساخت** برای ایمیج زندهٔ Arch Linux با میزکار Wayland و Hyprland، به‌همراه یک ویزارد
  کوچک پایتونی که همان ایمیج را دانلود می‌کند.
- یک **نمونهٔ آزمایشی**: نقطهٔ فعلی «ایمیج بوت می‌شود و میزکار می‌آید» است. نصب روی دیسک، Secure Boot،
  به‌روزرسانی، بازیابی و تنظیم خودکار سخت‌افزار **پیاده‌سازی نشده‌اند**.
- **کد باز و با لایسنس MIT**: اسکریپت‌ها، پیکربندی و کد تصویری ما تحت [LICENSE](LICENSE) قابل استفاده،
  تغییر، آینه‌کردن و بازتوزیع است.
- **قابل ساخت از بسته‌های عمومی**: ایمیج با ابزار رسمی `archiso` از بسته‌های مخزن عمومی Arch ساخته
  می‌شود. ما آن بسته‌ها را میزبانی، وصله یا دوباره لایسنس نمی‌کنیم.

### این پروژه چه چیزی نیست

- **وابسته به Arch Linux نیست.** «Arch Linux» علامت تجاری پروژهٔ Arch و نگه‌داران آن است؛ پرایم‌اواس فقط
  از بسته‌های عمومی و پروفایل رسمی `archiso` آن‌ها استفاده می‌کند.
- **وابسته به Hyprland، Waybar، Wofi، Kitty، Dunst، PipeWire، Firefox، Steam، Lutris، NVIDIA، AMD یا
  Intel نیست.** این نام‌ها فقط برای توصیف محتوای ایمیج ذکر می‌شوند.
- **توزیع‌کنندهٔ نرم‌افزار اختصاصی نیست.** ایمیج فقط شامل بسته‌هایی است که در زمان ساخت در مخازن عمومی
  Arch موجودند. اجزای اختصاصی (مثل کلاینت Steam یا بسته‌های درایور NVIDIA) از مخازن خود Arch و زیر
  **شرایط و لایسنس خودشان** می‌آیند؛ این پروژه آن‌ها را همراه نمی‌کند، کرک یا وصله نمی‌کند، آینه
  نمی‌کند و حق استفاده از آن‌ها را به شما نمی‌دهد. پذیرش آن شرایط با خود شماست.
- **وعدهٔ عملکرد نیست.** هیچ جمله‌ای در این پروژه به معنای «همهٔ بازی‌ها اجرا می‌شوند»، «بدون لگ»،
  «سریع‌تر از ویندوز» یا هر ادعای محک‌نشدهٔ دیگری نیست. هیچ عدد عملکردی بدون اندازه‌گیری منتشر نمی‌شود و
  نتیجه به GPU، درایور، بازی و پیکربندی بستگی دارد.
- **جایگزین سیستم‌عامل شما نیست.** روی چیزی نصب نمی‌شود، خودش پارتیشنی تغییر نمی‌دهد و هیچ تلمتری،
  حساب کاربری، لایسنس یا نسخهٔ پولی ندارد.
- **مرز امنیتی نیست.** ایمیج زنده با جلسهٔ ورود خودکار یک محیط آزمایشی است، نه سیستم سخت‌شده. روی
  دستگاهی که کنترلش نمی‌کنید اجرا نکنید و فرض نکنید داده‌های یک دیسک متصل در امان است.

### ایمنی و از دست رفتن داده

1. **اول در ماشین مجازی تست کنید.** `qemu-system-x86_64` با CD-ROM فقط-خواندنی هیچ تغییری روی میزبان
   نمی‌دهد.
2. **ایمیج را روی دیسکی که اطلاعات دارد ننویسید.** نوشتن ISO روی درایو اشتباه آن را پاک می‌کند و این
   کار با ابزار خود شما انجام می‌شود، نه توسط این مخزن.
3. **هیچ ضمانتی وجود ندارد.** نرم‌افزار «همان‌گونه که هست» ارائه می‌شود، بدون هیچ ضمانتی، همان‌طور که
   در لایسنس MIT آمده است.
4. **پشتیبانی تضمینی نیست.** پاسخ به issue و pull request داوطلبانه و در حد توان است.

### یکپارچگی چیزی که دانلود می‌کنید

- ویزارد فقط آدرس‌های **HTTPS** و فقط از مسیر `releases/download/` همین مخزن را می‌پذیرد.
- دانلود در فایل `.part` انجام می‌شود، با `Content-Length` مقایسه می‌شود و اگر Release فایل checksum
  داشته باشد، **SHA-256** منتشرشده هم بررسی می‌شود؛ در صورت عدم تطابق فایل پاک می‌شود، نه بوت.
- اسکریپت‌های نصب با **هش‌های پین‌شدهٔ SHA-256** بررسی می‌شوند و عمداً «fail closed» رفتار می‌کنند.
- ماژول تصویری `you.py` روی HTTPS گرفته می‌شود، هشش بررسی می‌شود و فقط **پارس** می‌شود، هرگز اجرا نه.
- ایمیج‌های منتشرشده توسط GitHub Actions و از همین سورس ساخته می‌شوند، پس هر ایمیج به یک کامیت قابل
  ردیابی است و لاگ بیلد به‌عنوان artifact نگه داشته می‌شود.

اگر هر یک از این بررسی‌ها روی سیستم شما شکست خورد، **ایمیج را بوت نکنید** و گزارش دهید.

### وضعیت پروژه

| بخش | وضعیت |
| --- | --- |
| ساخت ایمیج زنده | کار می‌کند (در GitHub Actions، یا محلی با Docker) |
| ویزارد دانلود (ویندوز/لینوکس/مک) | پیاده‌سازی شده؛ ایمیج را دانلود و بررسی می‌کند |
| نصب‌کنندهٔ دیسک | **پیاده‌سازی نشده** |
| Secure Boot / زنجیرهٔ بوت امضاشده | **پیاده‌سازی نشده** |
| به‌روزرسانی، بازیابی، بازگشت | **پیاده‌سازی نشده** |
| تنظیم خودکار سخت‌افزار | **پیاده‌سازی نشده** (ویزارد فقط ترجیحات را ذخیره می‌کند) |
| فهرست سخت‌افزار آزمایش‌شده | **هنوز هیچ** — گزارش‌ها پذیرفته می‌شوند |

اگر به نظرمی‌رسد محتوایی در این مخزن به حقوق شما تجاوز می‌کند، در GitHub یک issue باز کنید؛ محتوا
بی‌درنگ حذف یا اصلاح می‌شود.
