# Python interface functions for simplenote.vim

import SimplenoteCmd

def SimplenoteTrash():
    interface.trash_current_note()

try:
    SimplenoteCmd.Cred()
    SimplenoteTrash()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    Simplenote.Cmd.reset_user_pass('Login Failed')

# vim: expandtab
