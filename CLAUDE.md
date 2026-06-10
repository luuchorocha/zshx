# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A vanilla zsh configuration — **no plugin manager or framework** (no oh-my-zsh, zinit, prezto,
etc.). All behavior is implemented directly with zsh builtins, split across a handful of
single-topic module files. `~/.zshrc` is normally a symlink to `zshx` (the entry point); it may
be temporarily disconnected while iterating.

## How the config loads

`zshx` is the entry point. It auto-discovers every regular file in `~/.config/zshx/zshx.d/` and
sources them in lexicographic order. Module filenames carry a **numeric prefix** that defines load
order — there is no hardcoded list inside `zshx`.

Current modules:
- `10-common` — `bindkey -e` (emacs keybindings), prepends `~/.bin` and `~/.local/bin` to `PATH`
- `20-colors` — exports `LS_COLORS` and aliases `ls --color=auto`
- `30-history` — `HISTFILE` / `HISTSIZE` / `SAVEHIST`
- `40-aliases` — empty placeholder (slot reserved for user aliases)
- `50-prompt` — `promptinit` + `PROMPT` / `RPROMPT`
- `60-autocomplete` — `compinit` + `zstyle` completion settings

Modules are sourced (`.`) into the running interactive shell, not executed as subprocesses — so the
shebang line in each file is cosmetic (`20-colors` even uses a `bash` shebang; harmless).

A module that fails to source emits `zshx: failed to source <name>` to stderr; the cargador keeps
going with the next module. This replaces the original `|| true > /dev/null 2>&1` (which was a
no-op — the `||` consumed the failure before the redirection could silence it).

### Load order matters (cross-module dependency)
`60-autocomplete` sets `zstyle ':completion:*' list-colors ${LS_COLORS}`, so `20-colors` must load
**before** it — the numeric prefix enforces this implicitly (20 < 60). When choosing a prefix for a
new module, leave room for inserts (the gaps of 10 are deliberate).

A file without a numeric prefix still loads — its "short name" (used by `ZSHX_SKIP`/`ZSHX_ONLY`)
is just the full filename. It sorts after every prefixed module in the default locale.

## Adding a new module
1. Create a file in `~/.config/zshx/zshx.d/` with the appropriate numeric prefix
   (lowercase, no extension; `chmod +x` to match the others).
   - Reserved slots so far: 10, 20, 30, 40, 50, 60. Pick a free decade (e.g. 70-) for things
     that should load after everything, or a gap (e.g. 25-) to insert between existing modules.
2. That's it — no edit to `zshx` is needed.

## Environment overrides

The cargador honors three env vars (set them before sourcing `~/.zshrc`):

- `ZSHX_PROFILE=1` — print `<short-name> <ms>` to stderr for each module. Useful to spot slow
  ones (typically `compinit` in `60-autocomplete` or `promptinit` in `50-prompt`).
- `ZSHX_SKIP="a,b,c"` — comma-separated short names to skip. Example:
  `ZSHX_SKIP=autocomplete zsh` boots without completion init, useful for bisecting bugs.
- `ZSHX_ONLY="a,b"` — load only the listed short names. Complement of `SKIP`. Both can be
  combined; `ONLY` is applied first, then `SKIP`.

Short names are the filename **without** the numeric prefix, e.g. `autocomplete`, not
`60-autocomplete`.

## Applying & checking changes
- Apply edits: `exec zsh` (clean restart) or `source ~/.zshrc` (re-source in place).
- Syntax-check a module without running it: `zsh -n ~/.config/zshx/zshx.d/<module>`.
- Profile a clean boot in isolation: `zsh -dfc 'ZSHX_PROFILE=1 source ~/.config/zshx/zshx'`
  (`-d -f` skip system and user zshrc, so only this code runs).

There is no build, test, or lint tooling in this repo.

## Editing the prompt
`50-prompt` uses zsh prompt-expansion escapes: `%T` (time), `%d` (cwd), `%?` (last exit code), and the
`%(x.true.false)` ternary — `%(?...)` tests last-command success, `%(!...)` tests root. `RPROMPT`
shows the exit code only on failure. Colors are truecolor spans: `%F{#rrggbb}` … `%f`.

## Cargador internals (`zshx`)

The cargador defines `_zshx_load`, runs it, and `unset -f`s it so nothing leaks into the
interactive shell namespace. Notable zsh idioms:

- `*(N.)` — glob qualifier. `N` returns an empty list (instead of an error) if `zshx.d/` is empty;
  `.` filters to regular files only, skipping directories.
- `${name#<->-}` — strips a leading numeric-dash prefix. `<->` is zsh's class for "any integer", so
  `10-common` → `common` and `myfile` → `myfile` (unchanged if no prefix).
- `${array[(Ie)elem]}` — returns the 1-based index of `elem` in `array`, or 0 if absent.
  `(I)` means "last match", `(e)` means "exact, no pattern". Used as a membership predicate
  inside arithmetic `(( ... ))`.
- `$EPOCHREALTIME` — fractional seconds since epoch (from `zmodload zsh/datetime`). Lets profiling
  measure a `source` without forking `date`.
