# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A vanilla zsh configuration — **no plugin manager or framework** (no oh-my-zsh, zinit, prezto,
etc.). All behavior is implemented directly with zsh builtins, split across a handful of
single-topic module files. `~/.zshrc` is a symlink to `rc`, which is the entry point.

## How the config loads

`rc` defines a `load()` helper and calls it with an ordered list of module names:

    load \
      common \
      colors \
      history \
      aliases \
      prompt \
      autocomplete

`load()` sources each named file from `$HOME/.config/zsh/` **only if it exists** (`[ -e ]` guard).
Modules are sourced (`.`) into the running interactive shell, not executed as subprocesses — so the
shebang line in each file is cosmetic (`colors` even uses a `bash` shebang; harmless). **Load order
is significant.**

Each module owns one topic:
- `common` — `bindkey -e` (emacs key bindings)
- `colors` — exports `LS_COLORS` and aliases `ls --color=auto`
- `history` — `HISTFILE` / `HISTSIZE` / `SAVEHIST`
- `prompt` — `promptinit` + `PROMPT` / `RPROMPT`
- `autocomplete` — `compinit` + `zstyle` completion settings

### Load order matters (cross-module dependency)
`autocomplete` sets `zstyle ':completion:*' list-colors ${LS_COLORS}`, so `colors` must load
**before** `autocomplete` or completion coloring breaks. Keep `colors` ahead of `autocomplete`.

### `aliases` is wired but not yet present
The `load` list references `aliases`, but no such file exists — `load()` silently skips it. To add
aliases, just create `~/.config/zsh/aliases`; it is already slotted into the load order (after
`history`, before `prompt`), so **no edit to `rc` is needed**.

## Adding a new module
1. Create a file named for its topic in `~/.config/zsh/` (lowercase, no extension; `chmod +x` to
   match the others).
2. Add its name to the `load \` list in `rc`, positioned after anything it depends on (e.g. anything
   reading `LS_COLORS` goes after `colors`).

A file that isn't in the `load` list is never sourced.

## Applying & checking changes
- Apply edits: `exec zsh` (clean restart) or `source ~/.zshrc` (re-source in place).
- Syntax-check a module without running it: `zsh -n ~/.config/zsh/<module>`.

There is no build, test, or lint tooling in this repo.

## Editing the prompt
`prompt` uses zsh prompt-expansion escapes: `%T` (time), `%d` (cwd), `%?` (last exit code), and the
`%(x.true.false)` ternary — `%(?...)` tests last-command success, `%(!...)` tests root. `RPROMPT`
shows the exit code only on failure. Colors are truecolor spans: `%F{#rrggbb}` … `%f`.
