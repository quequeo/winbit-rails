# Allow starting OmniAuth flows via GET.
#
# OmniAuth 2.x defaults to POST-only for the request phase to mitigate CSRF.
# This app currently starts OAuth via a simple <a href="..."> from the SPA,
# so we allow GET in addition to POST.
#
# If you want stricter CSRF protection, switch the frontend to POST instead.
OmniAuth.config.allowed_request_methods = %i[get post]

# We intentionally allow GET for local/dev convenience; silence the warning spam.
OmniAuth.config.silence_get_warning = true
