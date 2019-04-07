def SimplenoteVersionInfo():
    try:
        interface.version_of_current_note()
    except KeyError:
        # Just incase it is tried on a note that isn't a simplenote
        print("This isn't a Simplenote")

try:
    set_cred()
    SimplenoteVersionInfo()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed. Check token?')

# vim: expandtab
