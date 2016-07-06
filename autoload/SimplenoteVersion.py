# Python interface functions for simplenote.vim

import SimplenoteCmd

def SimplenoteVersion():
    optionsexist = True if (float(vim.eval("a:0"))>=1) else False
    try:
        if optionsexist:
            interface.version_of_current_note(vim.eval("a:1"))
        else:
            interface.version_of_current_note("0")
    except KeyError:
        # Just incase it is tried on a note that isn't a simplenote
        print("This isn't a Simplenote")

try:
    SimplenoteCmd.Cred()
    SimplenoteVersion()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    Simplenote.Cmd.reset_user_pass('Login Failed')

# vim: expandtab
