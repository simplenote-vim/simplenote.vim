def SimplenotePin():
    interface.pin_current_note()

try:
    set_cred()
    SimplenotePin()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed. Check token?')

# vim: expandtab
