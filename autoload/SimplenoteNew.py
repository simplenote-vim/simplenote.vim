def SimplenoteNew():
    interface.create_new_note_from_current_buffer()

try:
    set_cred()
    SimplenoteNew()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed. Check token?')

# vim: expandtab
