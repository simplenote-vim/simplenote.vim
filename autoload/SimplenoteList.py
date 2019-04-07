def SimplenoteList():
    if (float(vim.eval("a:0"))>=1):
        try:
            # check for valid date string
            datetime.datetime.strptime(vim.eval("a:1"), "%Y-%m-%d")
            interface.list_note_index_in_scratch_buffer(since=vim.eval("a:1"))
        except ValueError:
            interface.list_note_index_in_scratch_buffer(tags=vim.eval("a:1").split(","))
    else:
        interface.list_note_index_in_scratch_buffer()

try:
    set_cred()
    SimplenoteList()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed. Check token?')

# vim: expandtab
