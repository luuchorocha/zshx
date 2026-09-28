# zshx

A lightweight, framework-free zsh configuration that loads a directory of small module files in order.

This repo is intentionally simple: there is no plugin manager, no opinionated framework, and no hardcoded config list. Instead, the entry point (`zshx`) auto-discovers every regular file in `~/.config/zshx/zshx.d/` and sources them in lexicographic order.

## What it gives you

- Emacs-style keybindings with `bindkey -e`
- PATH updates for `~/.bin` and `~/.local/bin`
- Colorized `ls`
- Shell history configuration
- Prompt setup and completion configuration
- Easy module-based customization without editing a single large config file

## Repository layout

- `zshx` — entry point that loads all modules
- `zshx.d/` — module directory, each file is sourced in numeric order
  - `10-common` — base shell settings and PATH
  - `20-colors` — LS colors and alias setup
  - `30-history` — history environment variables
  - `40-aliases` — reserved slot for user aliases
  - `50-prompt` — prompt configuration
  - `60-autocomplete` — completion setup

## Install

1. Put this repository somewhere like:

   ```sh
   mkdir -p ~/.config
   git clone <your-fork-or-repo-url> ~/.config/zshx
   ```

2. Link the entry point into your shell startup:

   ```sh
   ln -sf ~/.config/zshx/zshx ~/.zshrc
   ```

3. Reload zsh:

   ```sh
   exec zsh
   ```

## Adding modules

Create a file in `~/.config/zshx/zshx.d/` with a numeric prefix such as `70-my-module` or `25-extra-settings`.

The prefix controls load order, and the loader strips the leading numeric portion when applying `ZSHX_SKIP` and `ZSHX_ONLY` filters.

Example:

```sh
~/.config/zshx/zshx.d/25-git-settings
```

That file will be loaded automatically without touching the main entry point.

## Environment overrides

The loader supports these variables before sourcing your shell config:

```sh
export ZSHX_PROFILE=1
export ZSHX_SKIP="autocomplete,git"
export ZSHX_ONLY="common,prompt"
```

- `ZSHX_PROFILE=1` prints timing information for each loaded module
- `ZSHX_SKIP="a,b,c"` skips matching module names
- `ZSHX_ONLY="a,b"` loads only the listed modules

## Notes

- Modules are sourced into the current interactive shell, not executed as child processes.
- Numeric prefixes are intentional and help keep ordering predictable as the config grows.
- This repo intentionally has no build/test pipeline; it is a configuration repository.

## License

This project does not currently declare a license.
