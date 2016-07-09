def SimplenoteOpen():
    optionsexist = True if (float(vim.eval("a:0"))>=1) else False
    if optionsexist:
        interface.display_note_in_scratch_buffer(vim.eval("a:1"))
    else:
        print("No notekey given.")

try:
    set_cred()
    SimplenoteOpen()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed')

# vim: expandtab
