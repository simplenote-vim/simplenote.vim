# Python interface functions for simplenote.vim

import SimplenoteCmd

def SimplenoteNew():
        interface.create_new_note_from_current_buffer()

try:
    SimplenoteCmd.Cred()
    SimplenoteNew()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    Simplenote.Cmd.reset_user_pass('Login Failed')

# vim: expandtab
