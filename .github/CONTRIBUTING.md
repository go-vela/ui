# Contributing

## Getting Started

We'd love to accept your contributions to this project! If you are a first time contributor, please review our [Contributing Guidelines](https://go-vela.github.io/docs/community/contributing_guidelines/) before proceeding.

### Prerequisites

- [Review the commit guide we follow](https://chris.beams.io/posts/git-commit/#seven-rules) - ensure your commits follow our standards
- [Review our style guide](https://go-vela.github.io/docs/community/contributing_guidelines/#style-guide) to ensure your code is clean and consistent
- [Review the local development docs](..//DOCS.md) - ensures you have the Vela application stack running locally

### Setup

* [Fork](/fork) this repository

* Clone this repository to your workstation:

```bash
# clone the project
git clone git@github.com:go-vela/ui.git $HOME/go-vela/ui
```

* Navigate to the repository code:

```bash
# change into the cloned project directory
cd $HOME/go-vela/ui
```

* Point the original code at your fork:

```bash
# add a remote branch pointing to your fork
git remote add fork https://github.com/your_fork/ui
```

### Development

**Please review the [local development documentation](../DOCS.md) for more information.**

* Navigate to the repository code:

```bash
# change into the cloned project directory
cd $HOME/go-vela/ui
```

* Write your code and tests to implement the changes you desire.

* Run the repository code (ensures your changes perform as you desire):

```bash
# execute the `up` target with `make`
make up
```

* Test the repository code (ensures your changes don't break existing functionality):

```bash
# execute the `test` target with `make`
make test

# execute the `test-cypress` target with `make`
make test-cypress
```

* (Optional) Analyze the repository code (ensures your code follows best practices):

```bash
# analyze the code to see if anything isn't following recommended guidelines
elm-analyse --serve

# navigate to http://localhost:3000 to view analyze results
open http://localhost:3000
```

* Lint the repository code (ensures your code meets the project standards):

```bash
# capture a list of issues found by the linter
npm run lint

# if any issues are present, attempt to fix them automatically
npm run lint:fix
```

* Push to your fork:

```bash
# push your code up to your fork
git push fork master
```

* Make sure to follow our [PR process](https://go-vela.github.io/docs/community/contributing_guidelines/#development-workflow) when opening a pull request

Thank you for your contribution!

## Tips

### Visual Studio Code Users

- Check out the [Elm extension by Elm tooling](https://marketplace.visualstudio.com/items?itemName=Elmtooling.elm-ls-vscode) (elmtooling.elm-ls-vscode). It will help make `elm-format` and `elm-analyse` and automatic thing and provide other niceties.

- Enable the [stylelint extension](https://marketplace.visualstudio.com/items?itemName=stylelint.vscode-stylelint) - you might want to check their readme for some pointers with issues you might run into.

- Enable the [Prettier extension](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)

### IntelliJ Users

- There is a great [Elm plugin by Keith Lazuka](https://plugins.jetbrains.com/plugin/10268-elm/), made by a few people at Microsoft, for IntelliJ available.

### Vim Users

- These are the most referenced plugins for Vim, your milage may vary:

  - [elm-tooling/elm-vim](https://github.com/elm-tooling/elm-vim)
  - [ElmCast/elm-vim](https://github.com/ElmCast/elm-vim)
  - [prettier/vim-prettier](https://github.com/prettier/vim-prettier)
  - [dense-analysis/ale](https://github.com/dense-analysis/ale) (supports stylelint)

## Credit

The project setup is loosely based on Elm Batteries.
Learn more at the [Elm Batteries Documentation](https://github.com/cedricss/elm-batteries#table-of-contents)
