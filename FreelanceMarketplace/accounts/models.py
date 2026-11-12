"""
The user model is mapped onto the `users` table that already exists in the
PostgreSQL database of assignment 2 (database/schema.sql).

`managed = False` tells Django NOT to create/alter that table: the SQL scripts in
`database/` stay the single source of truth for the schema. The only change we
made to it is the extra `last_login` column (database/migrations/002_*.sql),
which Django's login machinery needs.
"""
from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models


class UserManager(BaseUserManager):
    def get_by_natural_key(self, email):
        # e-mail is unique case-insensitively in the database (lower(email) index)
        return self.get(email__iexact=email.strip())

    def create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("The e-mail address is required")
        user = self.model(email=email.strip().lower(), **extra_fields)
        user.set_password(password)  # hashed with Argon2 (see PASSWORD_HASHERS)
        user.save(using=self._db)
        return user


class User(AbstractBaseUser):
    STATUS_ACTIVE = "active"
    STATUS_INACTIVE = "inactive"
    STATUS_BLOCKED = "blocked"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "فعال"),
        (STATUS_INACTIVE, "غیرفعال"),
        (STATUS_BLOCKED, "مسدود"),
    ]

    # users.id is BIGINT GENERATED ALWAYS AS IDENTITY (the database creates it)
    id = models.BigAutoField(primary_key=True)
    first_name = models.CharField("نام", max_length=100)
    last_name = models.CharField("نام خانوادگی", max_length=100)
    email = models.EmailField("ایمیل", max_length=255, unique=True)
    phone = models.CharField("شماره موبایل", max_length=20, null=True, blank=True)
    # the hash lives in the column `password_hash` (never the plain password)
    password = models.CharField("password", max_length=255, db_column="password_hash")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    # last_login is inherited from AbstractBaseUser (added to the table by migration 002)

    objects = UserManager()

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS = ["first_name", "last_name"]

    class Meta:
        managed = False
        db_table = "users"

    @property
    def is_active(self):
        # Django refuses to log in users that are not active
        return self.status == self.STATUS_ACTIVE

    def get_full_name(self):
        return f"{self.first_name} {self.last_name}".strip()

    def get_short_name(self):
        return self.first_name

    def __str__(self):
        return self.email
