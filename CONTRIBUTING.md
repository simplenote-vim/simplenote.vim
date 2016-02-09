# simplenote.vim

## Contribute

### You already have code or an idea for code you want to contribute

- Fork the project
- Make your additions/fixes/improvements
- Run tests if you can (see below)
- Add new tests if you can and if appropriate
- Send a pull request

### You don't already have code, nor any ideas for code, but still want to contribute code somehow:

- Have a look through issues labelled "easier" or "harder" depending on how ambitious you are feeling
- Then run through the steps as per above
- Feel free to link to your fork in the issue before submitting a pull request if you want a review
- Or just open the pull request. A pull request doesn't have to start with the finished code

### You have ideas/bugs:

- Just open an issue with ideas for features or bugs you have found

## Tests

Unit testing uses [Vader](https://github.com/junegunn/vader.vim) which you will need to install. To run the tests, from within the checkout directory:

	vim -u tests/test-vimrc +Vader tests/simplenote.vader
