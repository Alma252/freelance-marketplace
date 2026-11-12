from django.contrib import messages
from django.contrib.auth import logout
from django.contrib.auth.decorators import login_required
from django.db import IntegrityError, transaction
from django.shortcuts import redirect, render
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_POST

from .forms import SignUpForm


def home(request):
    """The site root sends people to the right page."""
    if request.user.is_authenticated:
        return redirect("accounts:welcome")
    return redirect("accounts:login")


def signup(request):
    if request.user.is_authenticated:
        return redirect("accounts:welcome")

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
                messages.success(request, "حساب شما با موفقیت ساخته شد. اکنون وارد شوید.")
                return redirect("accounts:login")
    else:
        form = SignUpForm()
    return render(request, "accounts/signup.html", {"form": form})


@never_cache
@login_required
def welcome(request):
    """Temporary page shown after a successful login (login required)."""
    return render(request, "accounts/welcome.html")


@require_POST
def logout_view(request):
    """Ends the session. POST only (the logout button is a small form)."""
    logout(request)
    messages.success(request, "با موفقیت از حساب خود خارج شدید.")
    return redirect("accounts:login")
