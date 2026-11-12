# Prime-OS

Prime-OS پروژه‌ای آزمایشی برای ساخت لینوکس گیمینگ بر پایهٔ Arch Linux و محیط گرافیکی Hyprland است.

> **وضعیت فعلی:** هنوز فایل ISO منتشرشده یا نصب‌کنندهٔ دیسک نداریم. ویزارد فعلی هیچ دیسکی را پارتیشن‌بندی، فرمت، فلش یا جایگزین ویندوز نمی‌کند. مقدار RAM و GPU که انتخاب می‌کنی فعلاً فقط به‌عنوان ترجیح ذخیره می‌شود؛ برنامهٔ معمولی نمی‌تواند درصدی از GPU فیزیکی را برای سیستم‌عاملی که هنوز نصب نشده رزرو کند.

## اجرای نصب‌کنندهٔ نمایشی با یک دستور

این فرمان فایل‌های برنامه و تصویر فروهر را از مخزن عمومی GitHub می‌گیرد، محیط Python جداگانه می‌سازد و ویزارد گرافیکی را اجرا می‌کند. برای Linux/macOS به `bash`، `curl`، `git` و Python 3 و در Windows به PowerShell، Git و Python 3 نیاز است.

### Linux / macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh)
```

اگر process substitution در shell تو پشتیبانی نمی‌شود:

```bash
curl -fsSLO https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.sh && bash install.sh
```

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 | iex
```

برای بررسی فایل پیش از اجرا:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/fem-dev/Prime-OS/main/install.ps1 -OutFile install-prime-os.ps1
notepad .\install-prime-os.ps1
.\install-prime-os.ps1
```

## ویزارد الان چه می‌کند؟

1. فایل‌های برنامه را از همین مخزن عمومی GitHub دانلود می‌کند.
2. نسخه‌های GitHub را بررسی می‌کند. **اگر بعداً نسخه‌ای با فایل ISO منتشر شود** آن را دانلود می‌کند و فروهر را دقیقاً به‌اندازهٔ بایت‌های دریافت‌شده رنگی می‌کند. در حال حاضر هنوز ISOای منتشر نشده؛ بنابراین برنامه صادقانه همین را نشان می‌دهد، نه دانلود نمایشیِ تقلبی.
3. مقدار RAM و هدف درصد GPU را می‌پرسد و در `~/.config/prime-os/setup.json` ذخیره می‌کند (در Windows: `%USERPROFILE%\.config\prime-os\setup.json`). این مقدارها رزرو واقعی سخت‌افزار نیستند.
4. پس از انتشار ISO واقعی و آزمایش‌شده، می‌توان آن را از USB یا در ماشین مجازی بوت کرد. این ویزارد خودش سیستم‌عامل را روی رایانه نصب نمی‌کند.

لودر فقط به Python 3 و Pillow نیاز دارد. نمایش تصویر با عملیات بومی Pillow انجام می‌شود تا حلقهٔ پردازش پیکسلی Python انیمیشن دانلود را کند نکند.

## بررسی برای توسعه‌دهنده‌ها

```bash
python -m pip install -r requirements.txt
python -m py_compile loader.py
python loader.py
```

برای ساخت ISO زندهٔ آزمایشی، از Arch Linux استفاده کن و دستورهای `build.sh` را بررسی کن. ساخت کامل ISO هنوز در ماشین مجازی Arch و روی سخت‌افزار گیمینگ واقعی تأیید نشده است.
