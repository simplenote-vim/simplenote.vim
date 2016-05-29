# Python interface functions for simplenote.vim

def reset_user_pass(warning=None):
    if int(vim.eval("exists('g:SimplenoteUsername')")) == 0:
        vim.command("let s:user=''")
    if int(vim.eval("exists('g:SimplenotePassword')")) == 0:
        vim.command("let s:password=''")
    if warning:
        vim.command("redraw!")
        vim.command("echohl WarningMsg")
        vim.command("echo '%s'" % warning)
        vim.command("echohl none")

def Simplenote_cmd():
    if vim.eval('s:user') == '' or vim.eval('s:password') == '':
        try:
            vim.command("let s:user=input('email:', '')")
            vim.command("let s:password=inputsecret('password:', '')")
        except KeyboardInterrupt:
            reset_user_pass('KeyboardInterrupt')
            return
    # If a logon error has occurred, user may have corrected their globals since reset
    else:
        if vim.eval("exists('g:SimplenoteUsername')") == 1:
            vim.command("let s:user=g:SimplenoteUsername")
        if vim.eval("exists('g:SimplenotePassword')") == 1:
            vim.command("let s:password=g:SimplenotePassword")

    SN_USER = vim.eval("s:user")
    SN_PASSWORD = vim.eval("s:password")
    interface.simplenote.username = SN_USER
    interface.simplenote.password = SN_PASSWORD

    param = vim.eval("a:param")
    optionsexist = True if (float(vim.eval("a:0"))>=1) else False
    if param == "-l":
        if optionsexist:
            try:
                # check for valid date string
                datetime.datetime.strptime(vim.eval("a:1"), "%Y-%m-%d")
                interface.list_note_index_in_scratch_buffer(since=vim.eval("a:1"))
            except ValueError:
                interface.list_note_index_in_scratch_buffer(tags=vim.eval("a:1").split(","))
        else:
            interface.list_note_index_in_scratch_buffer()

    elif param == "-d":
        interface.trash_current_note()

    elif param == "-u":
        interface.update_note_from_current_buffer()

    elif param == "-n":
        interface.create_new_note_from_current_buffer()

    elif param == "-D":
        interface.delete_current_note()

    elif param == "-t":
        interface.set_tags_for_current_note()

    elif param == "-p":
        interface.pin_current_note()

    elif param == "-P":
        interface.unpin_current_note()

    elif param == "-v":
        try:
            if optionsexist:
                interface.version_of_current_note(vim.eval("a:1"))
            else:
                interface.version_of_current_note("0")
        except KeyError:
            # Just incase it is tried on a note that isn't a simplenote
            print("This isn't a Simplenote")

    elif param == "-V":
        try:
            interface.version_of_current_note()
        except KeyError:
            # Just incase it is tried on a note that isn't a simplenote
            print("This isn't a Simplenote")

    elif param == "-o":
        if optionsexist:
            interface.display_note_in_scratch_buffer(vim.eval("a:1"))
        else:
            print("No notekey given.")

    else:
        print("Unknown argument")
try:
    Simplenote_cmd()
except simplenote.SimplenoteLoginFailed:
    # Note: error has to be caught here and not in __init__
    reset_user_pass('Login Failed')
# vim: expandtab
