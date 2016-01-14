# simplenote.vim

## Contribute

### Code

- Fork the project
- Make your additions/fixes/improvements
- Run tests if you can (see below)
- Add new tests if you can and if  appropriate
- Send a pull request

### Ideas

- Just open an issue with ideas for features, etc

## Tests

Unit testing uses [Vader](https://github.com/junegunn/vader.vim) which you will need to install. To run the tests, from within the checkout directory:

	vim -u tests/test-vimrc +Vader tests/simplenote.vader
