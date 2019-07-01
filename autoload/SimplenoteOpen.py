def SimplenoteOpen():
    interface.display_note_in_scratch_buffer(vim.eval("a:noteid"))

try:
    set_cred()
    SimplenoteOpen()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed. Check token?')
except TypeError:
    print("Invalid note key/id?")

# vim: expandtab
