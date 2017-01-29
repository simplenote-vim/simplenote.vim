# Python Credential functions for simplenote.vim

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

def set_cred():
    if vim.eval('s:user') == '' or vim.eval('s:password') == '':
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

    SN_USER = vim.eval("s:user")
    SN_PASSWORD = vim.eval("s:password")
    interface.simplenote.username = SN_USER
    interface.simplenote.password = SN_PASSWORD

# vim: expandtab
