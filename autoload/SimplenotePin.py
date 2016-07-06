# Python interface functions for simplenote.vim

import SimplenoteCmd

def SimplenotePin():
    interface.pin_current_note()

try:
    SimplenoteCmd.Cred()
    SimplenotePin()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    Simplenote.Cmd.reset_user_pass('Login Failed')

# vim: expandtab
