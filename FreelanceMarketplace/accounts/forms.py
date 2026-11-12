from django import forms
from django.contrib.auth import password_validation
from django.contrib.auth.forms import AuthenticationForm, PasswordResetForm, SetPasswordForm
from django.core.exceptions import ValidationError

from .models import User


class SignUpForm(forms.ModelForm):
    password1 = forms.CharField(
        label="رمز عبور",
        strip=False,
        widget=forms.PasswordInput(attrs={"autocomplete": "new-password"}),
        help_text=password_validation.password_validators_help_text_html(),
    )
    password2 = forms.CharField(
        label="تکرار رمز عبور",
        strip=False,
        widget=forms.PasswordInput(attrs={"autocomplete": "new-password"}),
    )

    class Meta:
        model = User
        fields = ("first_name", "last_name", "email")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.widget.attrs.setdefault("class", "input")
        self.fields["first_name"].widget.attrs["autofocus"] = True
        self.fields["first_name"].widget.attrs["autocomplete"] = "given-name"
        self.fields["last_name"].widget.attrs["autocomplete"] = "family-name"
        self.fields["email"].widget.attrs.update({"dir": "ltr", "autocomplete": "email"})
        self.fields["password1"].widget.attrs["dir"] = "ltr"
        self.fields["password2"].widget.attrs["dir"] = "ltr"

    def clean_email(self):
        # e-mails are stored in lower case; uniqueness is case-insensitive
        email = self.cleaned_data["email"].strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise ValidationError("این ایمیل قبلاً ثبت شده است.")
        return email

    def clean(self):
        cleaned = super().clean()
        p1 = cleaned.get("password1")
        p2 = cleaned.get("password2")
        if p1 and p2 and p1 != p2:
            self.add_error("password2", "رمز عبور و تکرار آن یکسان نیستند.")
        return cleaned

    def _post_clean(self):
        super()._post_clean()
        # validate the password strength once the instance has name/e-mail
        # (so "password similar to your name/e-mail" can be detected)
        p1 = self.cleaned_data.get("password1")
        p2 = self.cleaned_data.get("password2")
        if p1 and p1 == p2:
            try:
                password_validation.validate_password(p1, self.instance)
            except ValidationError as error:
                self.add_error("password1", error)

    def save(self, commit=True):
        user = super().save(commit=False)
        user.set_password(self.cleaned_data["password1"])  # Argon2 hash, never plain text
        if commit:
            user.save()
        return user


class LoginForm(AuthenticationForm):
    """E-mail + password login. One generic message for every failure, so the
    page never reveals whether the e-mail or the password was wrong (or whether
    the account exists / is blocked)."""

    error_messages = {
        "invalid_login": "ایمیل یا رمز عبور اشتباه است.",
        "inactive": "ایمیل یا رمز عبور اشتباه است.",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["username"].label = "ایمیل"
        self.fields["username"].widget.attrs.update(
            {"class": "input", "dir": "ltr", "autocomplete": "email", "autofocus": True}
        )
        self.fields["password"].label = "رمز عبور"
        self.fields["password"].widget.attrs.update(
            {"class": "input", "dir": "ltr", "autocomplete": "current-password"}
        )


class PasswordResetRequestForm(PasswordResetForm):
    """Step 1 of password recovery: the user types the account e-mail.

    Django generates a signed, time-limited, single-use link (see
    PASSWORD_RESET_TIMEOUT) and e-mails it. Our users table has no `is_active`
    column, so we override get_users() to use `status = 'active'` instead.
    """

    email = forms.EmailField(
        label="ایمیل",
        max_length=254,
        widget=forms.EmailInput(
            attrs={"autocomplete": "email", "class": "input", "dir": "ltr", "autofocus": True}
        ),
    )

    def get_users(self, email):
        users = User.objects.filter(email__iexact=email.strip(), status=User.STATUS_ACTIVE)
        return (user for user in users if user.has_usable_password())


class SetNewPasswordForm(SetPasswordForm):
    """Step 2: new password + repeat, with the same validation as sign-up."""

    error_messages = {
        **SetPasswordForm.error_messages,
        "password_mismatch": "رمز عبور و تکرار آن یکسان نیستند.",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["new_password1"].label = "رمز عبور جدید"
        self.fields["new_password2"].label = "تکرار رمز عبور جدید"
        for name in ("new_password1", "new_password2"):
            self.fields[name].widget.attrs.update(
                {"class": "input", "dir": "ltr", "autocomplete": "new-password"}
            )
        self.fields["new_password1"].widget.attrs["autofocus"] = True
