# Python Credential functions for simplenote.vim

def reset_user_pass(warning=None):
    if int(vim.eval("exists('g:SimplenoteUsername')")) == 0:
        vim.command("let s:user=''")
    if int(vim.eval("exists('g:SimplenotePassword')")) == 0:
        vim.command("let s:password=''")
    if int(vim.eval("exists('g:SimplenoteToken')")) == 0:
        vim.command("let s:token=''")
    if warning:
        vim.command("redraw!")
        vim.command("echohl WarningMsg")
        vim.command("echo '%s'" % warning)
        vim.command("echohl none")

def set_cred():
    if ((vim.eval('s:user') == '' or vim.eval('s:password') == '') and vim.eval('s:token') == ''):
        try:
            for variable, prompt in (
                ("s:user", "input('email:', '')"),
                ("s:password", "inputsecret('password:', '')")
            ):
                if vim.eval(variable) == '':
                    vim.command("let %s=%s" % (variable, prompt))
        except KeyboardInterrupt:
            reset_user_pass('KeyboardInterrupt')
            return
    # If a logon error has occurred, user may have corrected their globals since reset
    else:
        if vim.eval("exists('g:SimplenoteUsername')") == 1:
            vim.command("let s:user=g:SimplenoteUsername")
        if vim.eval("exists('g:SimplenotePassword')") == 1:
            vim.command("let s:password=g:SimplenotePassword")
        if vim.eval("exists('g:SimplenoteToken')") == 1:
            vim.command("let s:token=g:SimplenoteToken")

    SN_USER = vim.eval("s:user")
    SN_PASSWORD = vim.eval("s:password")
    SN_TOKEN = vim.eval("s:token")
    interface.simplenote.username = SN_USER
    interface.simplenote.password = SN_PASSWORD
    interface.simplenote.password = SN_TOKEN

# vim: expandtab
