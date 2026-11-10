#!/usr/bin/env python3
import sys

# Patch index.html to redirect to logout_url or /oauth2/sign_out on close
with open("/usr/share/xpra/www/index.html", "r") as f:
    c = f.read()

target = "client.callback_close = function(reason) {"
replacement = (
    "client.callback_close = function(reason) { "
    "window.location.href = (Utilities.getparam('logout_url') || window.XPRA_LOGOUT_URL || '/oauth2/sign_out'); "
    "return;"
)
if target in c:
    c = c.replace(target, replacement, 1)
    with open("/usr/share/xpra/www/index.html", "w") as f:
        f.write(c)

# Patch connect.html to prevent manual connect form
with open("/usr/share/xpra/www/connect.html", "r") as f:
    c2 = f.read()

script_inject = (
    "<script>"
    "var target = (window.location.search && new URLSearchParams(window.location.search).get('logout_url')) || '/oauth2/sign_out';"
    "window.location.replace(target);"
    "</script>"
)
if "<script>var target" not in c2:
    c2 = c2.replace("<head>", f"<head>{script_inject}", 1)
    with open("/usr/share/xpra/www/connect.html", "w") as f:
        f.write(c2)
