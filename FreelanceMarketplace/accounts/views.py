from django.contrib import messages
from django.db import IntegrityError, transaction
from django.shortcuts import redirect, render

from .forms import SignUpForm
from .models import User


def home(request):
    """Temporary page (step 2): proves that Django is connected to the database."""
    return render(request, "home.html", {"users_count": User.objects.count()})


def signup(request):
    if request.method == "POST":
        form = SignUpForm(request.POST)
        if form.is_valid():
            try:
                with transaction.atomic():
                    form.save()
            except IntegrityError:
                # two sign-ups with the same e-mail at the same moment:
                # the unique index of the database has the last word
                form.add_error("email", "این ایمیل قبلاً ثبت شده است.")
            else:
                # (step 4 will redirect to the login page instead)
                messages.success(request, "حساب شما با موفقیت ساخته شد. صفحه ورود در مرحله بعد اضافه می‌شود.")
                return redirect("accounts:home")
    else:
        form = SignUpForm()
    return render(request, "accounts/signup.html", {"form": form})
