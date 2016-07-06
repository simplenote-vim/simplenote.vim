# Python interface functions for simplenote.vim

import SimplenoteCmd

def SimplenoteversionInfo():
    try:
        interface.version_of_current_note()
    except KeyError:
        # Just incase it is tried on a note that isn't a simplenote
        print("This isn't a Simplenote")

try:
    SimplenoteCmd.Cred()
    SimplenoteVersionInfo()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    Simplenote.Cmd.reset_user_pass('Login Failed')

# vim: expandtab
