def SimplenoteTag():
    #TODO: Make this work with supplied args
    interface.set_tags_for_current_note()

try:
    set_cred()
    SimplenoteTag()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed. Check token?')

# vim: expandtab
