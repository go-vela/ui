# Local Development

## Prerequisites

1. `nvm use` to ensure you are using the right NodeJS version (see https://github.com/nvm-sh/nvm) - see [.nvmrc](.nvmrc) in the root of the project
1. Install elm-test (`npm i elm-test -g`) \*
1. Install elm-format (`npm i elm-format -g`) \*
1. Install elm-analyse (`npm i elm-analyse -g`) \*
1. Clone this repo
1. In the directory, run `npm install`

_\* this will install globally; we prefer to not have them as local dev dependencies at the moment._

## Create secrets for local development

```bash
# Copy the existing example .env.example to .env
cp .env.example .env
```

Now, edit the values for each of the environment variables in the newly created `.env` file.

Also, be sure to update `docker-compose.yml` by adjusting the value of `VELA_SOURCE_URL` to match the URL of your source control provider.

## Running locally

```bash
# Run the the whole stack except UI with `make`
make up

# Alternatively, run docker-compose directly
docker-compose -f docker-compose.yml up -d --build
```

_Note: you can also uncomment the `ui` service in [docker-compose.yml](../docker-compose.yml)
and follow the above to run the whole stack as Docker containers._

## Developing

To run the dev server with hot-reloading, do:

```bash
npm run dev
```

Visit [localhost:8888](http://localhost:8888/) to view the site.

You're ready to start adding/editing code. It should auto-refresh in the browser.

- Write your code and test locally
  - Please be sure to [follow our commit rules](https://chris.beams.io/posts/git-commit/#seven-rules)
- Write tests for your changes and ensure they pass

```bash
# Run Elm tests with (files a are located at /tests)
npm run test
```

```bash
# Run Cypress tests with (test files are located at /cypress/integration)
npm run test:cy

# .. or if you prefer the Cypress UI
npm run test:cy-open
```

### Before committing code

- run your code through `elm-format`

  ```bash
  # With make; this will run elm-format and elm-test
  make test

  # .. or run elm-format directly with
  elm-format --validate src/ tests/
  ```

  - (Bonus) Run `elm-analyse` and visit [localhost:3000](http://localhost:3000) to see if anything doesn't follow good practice

  ```bash
  elm-analyse --serve
  ```

- run through the other linters

  ```bash
  npm run lint
  ```

  If you encounter issues, you can attempt to autofix them with.
  Any remaining issues will have to be resolved manually.

  ```bash
  npm run lint:fix
  ```

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
