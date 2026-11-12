// Show / hide password buttons (works with mouse, touch and keyboard)
document.addEventListener("click", function (event) {
  var button = event.target.closest(".toggle-password");
  if (!button) { return; }
  var input = document.getElementById(button.dataset.target);
  if (!input) { return; }
  var show = input.type === "password";
  input.type = show ? "text" : "password";
  button.textContent = show ? "مخفی" : "نمایش";
  button.setAttribute("aria-pressed", show ? "true" : "false");
});
