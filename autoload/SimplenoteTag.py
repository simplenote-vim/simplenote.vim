# Python interface functions for simplenote.vim

import SimplenoteCmd

def SimplenoteTag():
    #TODO: Make this work with supplied args
    interface.set_tags_for_current_note()

try:
    SimplenoteCmd.Cred()
    SimplenoteTag()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    Simplenote.Cmd.reset_user_pass('Login Failed')

# vim: expandtab
