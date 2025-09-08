# Dotfiles (`~/.config`)

This repository contains my personal configuration files for tools I use daily.  
It lets me keep a consistent development environment across machines, and version-control my setup.

---

## Contents

Some of the key configs included here:

- **Terminal & Shell**
  - [`alacritty`](alacritty/alacritty.toml) – Alacritty terminal settings
  - [`fish`](fish/conf.d/atuin.env.fish) – Fish shell config
- **Tools**
  - [`atuin`](atuin/config.toml) – History sync settings
  - [`flipper`](flipper/settings.json) – Debugging tool
  - [`ghostty`](ghostty/themes/gruvbox-dark) – Terminal theme
  - [`git`](git/ignore) – Git ignore patterns
  - [`graphite`](graphite/) – CLI aliases and user config
  - [`jgit`](jgit/config) – Java Git configuration
  - [`jj`](jj/) – Jujutsu (jj) VCS config & helper scripts
  - [`karabiner`](karabiner/karabiner.json) – macOS keyboard remapping
  - [`sourcery`](sourcery/sourcery.yaml) – Sourcery project configuration
- **Custom scripts**
  - [`tools/`](tools/) – Various helper scripts and small projects

---

## Setup

1. **Clone the repo** into your home directory (or wherever you keep dotfiles):

   ```bash
   git clone git@github.com:yourname/dotfiles.git ~/.config
