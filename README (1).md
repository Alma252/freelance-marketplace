# Marketplace Freelance

پلتفرم فریلنسری **Marketplace Freelance** — پروژه درس آزمایشگاه مهندسی نرم‌افزار.

- **تمرین ۲:** طراحی و پیاده‌سازی پایگاه داده (PostgreSQL) — مستندات کامل در [docs/database.md](docs/database.md)
- **تمرین ۳ (این مرحله):** احراز هویت کاربران با **Django**: ورود، ثبت‌نام و بازیابی رمز عبور، متصل به همان دیتابیس




| *(شیدا عسکری سبزکوهی )* | پروژه انفرادی — طراحی، پیاده‌سازی و مدیریت مخزن |

## قابلیت‌ها

| صفحه | آدرس | توضیح |
|---|---|---|
| ثبت‌نام | `/signup/` | نام، نام خانوادگی، ایمیل، رمز و تکرار آن؛ اعتبارسنجی در Backend؛ جلوگیری از ایمیل تکراری |
| ورود | `/login/` | ایمیل و رمز، نمایش/مخفی‌کردن رمز، پیام خطای یکسان برای همه خطاهای ورود |
| خوش آمدید | `/welcome/` | صفحه موقت (فقط برای کاربر واردشده)، نمایش نام و شناسه، دکمه خروج |
| فراموشی رمز | `/password-reset/` | ثبت درخواست با ایمیل؛ پیام نتیجه وجود یا عدم وجود ایمیل را فاش نمی‌کند |
| تعیین رمز جدید | `/reset/<uid>/<token>/` | لینک اختصاصی، زمان‌دار (۳۰ دقیقه) و یک‌بارمصرف |

### نکات امنیتی
- رمز عبور فقط به‌صورت **هش Argon2** در ستون `users.password_hash` ذخیره می‌شود (هش‌کردن در Backend)؛ رمز ساده یا هش سریع (MD5/SHA-256) استفاده نشده است.
- پیام ورود ناموفق مشخص نمی‌کند ایمیل اشتباه است یا رمز؛ پیام بازیابی رمز هم وجود ایمیل را فاش نمی‌کند.
- سشن‌ها در دیتابیس ذخیره می‌شوند؛ دکمه «خروج» سشن را پایان می‌دهد و صفحه «خوش آمدید» بدون ورود قابل مشاهده نیست.
- همه فرم‌ها در سمت سرور هم اعتبارسنجی می‌شوند و محافظت CSRF دارند.
- اطلاعات محرمانه (کلید Django، رمز دیتابیس) در فایل `.env` هستند که با `.gitignore` از Git کنار گذاشته شده است.
- ایمیل یکتاست و به حروف بزرگ/کوچک حساس نیست (ایندکس یکتا روی `lower(email)` در دیتابیس).

## پیش‌نیازها
- Python 3.10 یا بالاتر (روی اوبونتو ممکن است لازم باشد: `sudo apt install python3-venv`)
- PostgreSQL 14 یا بالاتر

## روش اجرای برنامه

```bash
git clone <آدرس مخزن>
cd freelance-marketplace

# 1) دیتابیس
createdb lab_freelance          # اگر قبلاً ساخته نشده است
psql -d lab_freelance -v ON_ERROR_STOP=1 -f database/schema.sql
psql -d lab_freelance -v ON_ERROR_STOP=1 -f database/migrations/002_users_last_login.sql
psql -d lab_freelance -v ON_ERROR_STOP=1 -f database/seed.sql        # اختیاری (داده نمونه)

# 2) محیط مجازی و کتابخانه‌ها
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3) تنظیمات محلی
cd FreelanceMarketplace
cp .env.example .env
#   در فایل .env مقدارهای DJANGO_SECRET_KEY، DB_USER و DB_PASSWORD را پر کنید.
#   ساخت کلید:  python -c "import secrets; print(secrets.token_urlsafe(50))"

# 4) جدول‌های داخلی Django (سشن و ...) و اجرا
python manage.py migrate
python manage.py runserver
```

سپس <http://127.0.0.1:8000/> را باز کنید.

نکته‌ها:
- **ایمیل‌های توسعه** (مثل لینک بازیابی رمز) ارسال واقعی نمی‌شوند و در **ترمینالی که `runserver` در آن اجرا شده** چاپ می‌شوند.
- کاربران `database/seed.sql` هش‌های ساختگی دارند و نمی‌توانند وارد شوند؛ برای ورود از صفحه ثبت‌نام یک حساب جدید بسازید.
- اگر دسترسی به PyPI ندارید: `pip install -i https://mirror-pypi.runflare.com/simple -r requirements.txt`
- اگر `schema.sql` را دوباره اجرا کردید، فایل `002_users_last_login.sql` را هم دوباره اجرا کنید.

## ساختار مخزن

```
.
├── README.md
├── requirements.txt
├── database/                    # اسکریپت‌های PostgreSQL (تمرین ۲) + migrations
├── docs/                        # ERD و مستندات دیتابیس
└── FreelanceMarketplace/        # پروژه Django
    ├── manage.py
    ├── .env.example
    ├── FreelanceMarketplace/    # تنظیمات و urls پروژه
    ├── accounts/                # مدل کاربر (جدول users)، فرم‌ها و viewهای احراز هویت
    ├── templates/
    └── static/
```

مدل کاربر Django روی جدول `users` طراحی‌شده در تمرین ۲ سوار شده است (`managed = False`)، بنابراین ساختار دیتابیس همچنان با اسکریپت‌های SQL مدیریت می‌شود. تنها تغییر، ستون `last_login` است (`database/migrations/002_users_last_login.sql`).

## چک‌لیست سناریوهای ارزیابی

- [x] ورود موفق و ناموفق (پیام یکسان)
- [x] ثبت حساب جدید و ذخیره هش Argon2 در دیتابیس
- [x] جلوگیری از ثبت ایمیل تکراری (حتی با حروف بزرگ/کوچک متفاوت)
- [x] بازیابی رمز با لینک معتبر، رد لینک مصرف‌شده یا نامعتبر
- [x] ورود با رمز جدید
- [x] حفظ سشن و خروج؛ عدم دسترسی به صفحه «خوش آمدید» بدون ورود
