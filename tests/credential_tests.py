# -*- coding: utf-8 -*-
import unittest
import os
import sys

sys.path.append(os.path.join(os.path.realpath(os.path.dirname(__file__)), '..', 'autoload'))
from SimplenoteCmd import set_cred


class MockVim(object):

    def __init__(self):
        self.received_commands = []

    def eval(self, code):
        return ''

    def command(self, code):
        self.received_commands.append(code)


class SimplenoteStub(object):

    username = ''
    password = ''


class InterfaceStub(object):

    simplenote = SimplenoteStub()


class CredentialsTests(unittest.TestCase):

    def setUp(self):
        self.mock_vim = MockVim()
        __builtins__['vim'] = self.mock_vim
        __builtins__['interface'] = InterfaceStub()

    def tearDown(self):
        del __builtins__['vim']
        del __builtins__['interface']

    def received_commands_starting_with(self, string):
        return [
            c for c in self.mock_vim.received_commands
            if c.startswith(string)
        ]


    def test_asks_for_username_if_it_isnt_specified(self):
        set_cred()

        user_cred_assigns = self.received_commands_starting_with('let s:user=')
        self.assertEqual(len(user_cred_assigns), 1)

    def test_asks_for_password_if_it_isnt_specified(self):
        set_cred()

        pwd_cred_assigns = self.received_commands_starting_with('let s:password=')
        self.assertEqual(len(pwd_cred_assigns), 1)

    def test_doesnt_ask_for_username_if_it_is_specified(self):
        self.mock_vim.eval = lambda _: '<value>'

        set_cred()

        user_cred_assigns = self.received_commands_starting_with('let s:user=')
        self.assertEqual(len(user_cred_assigns), 0)

    def test_doesnt_ask_for_password_if_it_is_specified(self):
        self.mock_vim.eval = lambda _: '<value>'

        set_cred()

        pwd_cred_assigns = self.received_commands_starting_with('let s:password=')
        self.assertEqual(len(pwd_cred_assigns), 0)

    def test_asks_for_password_with_hidding_input(self):
        set_cred()

        pwd_cred_assigns = self.received_commands_starting_with('let s:password=')
        self.assertTrue('inputsecret' in pwd_cred_assigns[0])

    def test_asks_for_username_if_only_password_is_specified(self):
        self.mock_vim.eval = lambda c: '<value>' if c == 's:password' else ''

        set_cred()

        user_cred_assigns = self.received_commands_starting_with('let s:user=')
        self.assertEqual(user_cred_assigns, self.mock_vim.received_commands)

    def test_asks_for_password_if_only_username_is_specified(self):
        self.mock_vim.eval = lambda c: '<value>' if c == 's:user' else ''

        set_cred()

        pwd_cred_assigns = self.received_commands_starting_with('let s:password=')
        self.assertEqual(pwd_cred_assigns, self.mock_vim.received_commands)


if __name__ == '__main__':
    unittest.main()
