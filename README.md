# zellij.fish

## Description

`zellij.fish` is a [fish](https://fishshell.com) plugin that integrates with [zellij](https://zellij.dev/).

It comes with the following features:

- Update the tab title every time a command has run to completion. The tab title has the format `fish(<status>): <cwd> <jobs>`.
- Keybind `alt+o` to fuzzy search through the visible https urls on the screen with [fzf](https://github.com/junegunn/fzf) and open the selected url(s) in the default browser.
- Keybind `alt+a` to fuzzy search through the visible file paths on the screen with [fzf](https://github.com/junegunn/fzf) and append the selected url(s) at the cursor position.
- Keybind `alt+c` to fuzzy search through the visible file paths on the screen with [fzf](https://github.com/junegunn/fzf) and copy the selected url(s) to the clipboard.

## Demo

https://github.com/kpbaks/zellij.fish/assets/57013304/0c20c6a3-f618-4c28-93d8-82b7916104bc

## Installation

```fish
fisher install kpbaks/zellij.fish
```

## Customization

The following variables can be changed to customize the plugin: 0 and 1 are used to represent false and true respectively. `\e` is used to represent the alt key in fish keybinds. To use ctrl instead of alt, use `\c` instead of `\e`.

| Variable                  | Default   | Description                                                                                                                                 | Constraints                                                                        |
| ------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `ZELLIJ_FISH_KEYMAP_OPEN_URL` | `\eo`   | The keybind to open the fuzzy search for urls.                                                                                              | Must be a valid keybind understood by `bind`                                                            |
| `ZELLIJ_FISH_KEYMAP_ADD_URL_AT_CURSOR` | `\ea`   | The keybind to open the fuzzy search for file paths and append the selected url(s) at the cursor position.                                                                                              | Must be a valid keybind understood by `bind`                                                            |
| `ZELLIJ_FISH_KEYMAP_COPY_URL_TO_CLIPBOARD` | `\ec`   | The keybind to open the fuzzy search for file paths and copy the selected url(s) to the clipboard.                                                                                              | Must be a valid keybind understood by `bind`                                                            |
| `ZELLIJ_FISH_USE_FULL_SCREEN` | `0` | Whether to use the entire scrollback buffer for the fuzzy search or only the visible part of the screen.                                                                                              | Either `0` or `1` |
| `ZELLIJ_FISH_RENAME_TAB_TITLE` | `1` | Whether to rename the tab title after each command.                                                                                              | Either `0` or `1` |
