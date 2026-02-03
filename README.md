# dotfiles

Modern, cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Includes configurations for ZSH, tmux, starship prompt, and more.

## Features

- **ZSH Configuration**: Custom ZSH setup with plugins managed by [antidote](https://getantidote.github.io/)
  - Auto-suggestions
  - Syntax highlighting
  - Tab completions
  - Clipboard integration
- **Starship Prompt**: Beautiful, fast, and customizable prompt with Catppuccin Mocha theme
- **Tmux Configuration**: Enhanced terminal multiplexer setup with vim-like keybindings
  - TPM plugin manager
  - Vim-tmux navigator integration
  - Catppuccin theme
- **Cross-Platform**: Supports macOS, Ubuntu, and Manjaro Linux
- **Automated Installation**: Uses chezmoi for declarative configuration management

## Structure

```
.
├── home/
│   ├── .chezmoi.yaml.tmpl          # Chezmoi configuration template
│   ├── .chezmoiscripts/            # Automated setup scripts
│   ├── dot_zshrc                   # Main ZSH entry point
│   ├── run_before_01-install-zsh.sh # Pre-install script for ZSH
│   └── dot_config/
│       ├── zsh/
│       │   ├── dot_zshrc           # ZSH configuration
│       │   ├── bootstrap.zshrc     # Bootstrap functions and plugin loader
│       │   ├── aliases.zshrc       # Command aliases
│       │   └── dot_zsh_plugins.txt # Plugin list for antidote
│       ├── tmux/
│       │   └── tmux.conf           # Tmux configuration
│       └── starship/
│           └── starship.toml       # Starship prompt configuration
└── tests/                          # zunit tests for validation
```

## Requirements

### All Systems
- git
- chezmoi

### MacOS
- Homebrew package manager (brew)

### Ubuntu/Debian
- zsh (will be auto-installed if missing)

### Manjaro/Arch
- zsh (will be auto-installed if missing)

## Installation

### First-time Setup

1. Install chezmoi:

   ```bash
   # macOS
   brew install chezmoi

   # Ubuntu/Debian
   sudo snap install chezmoi --classic
   # or
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME

   # Arch/Manjaro
   sudo pacman -S chezmoi
   ```

2. Initialize with this repository:

   ```bash
   chezmoi init twitchel/dotfiles
   ```

3. Review what changes will be made:

   ```bash
   chezmoi diff
   ```

4. Apply the configuration:

   ```bash
   chezmoi apply
   ```

### Updating

To update your dotfiles after pulling new changes:

```bash
chezmoi update
```

### Manual Updates

If you want to manually pull and apply changes:

```bash
cd ~/.local/share/chezmoi
git pull
chezmoi apply
```

## Configuration

### ZSH

The ZSH configuration is split into modular files:
- `dot_zshrc` - Main entry point that sources the configuration directory
- `bootstrap.zshrc` - Loads antidote plugin manager and starship
- `aliases.zshrc` - Defines command aliases

Environment variable overrides can be placed in `~/.env` and will be automatically loaded.

### Starship

Starship configuration uses the Catppuccin Mocha color scheme and displays:
- Operating system icon
- Username
- Current directory
- Git branch and status
- Programming language versions (C, Rust, Go, Node.js, Python, etc.)
- Command duration
- Current time

### Tmux

Tmux is configured with:
- Prefix key: `Ctrl+s`
- Vim-style pane navigation
- Status bar at the top
- Catppuccin theme
- Plugin support via TPM

## Testing

This repository includes automated tests using [zunit](https://zunit.xyz/) to validate the dotfiles configuration.

### Running Tests

```bash
cd ~/.local/share/chezmoi
zunit tests
```

### Test Coverage

- ZSH configuration validation
- Environment variables
- Alias definitions
- Plugin loading
- Starship integration

## Customization

### Adding New Aliases

Edit `home/dot_config/zsh/aliases.zshrc` and add your aliases:

```bash
alias myalias="command"
```

### Adding ZSH Plugins

Add plugins to `home/dot_config/zsh/dot_zsh_plugins.txt`:

```
username/plugin-name
```

### Environment Variables

Add custom environment variables to `~/.env`:

```bash
MY_VARIABLE=value
```

## Troubleshooting

### ZSH not loading properly

Check if the `ZSH_SOURCED` environment variable is set:

```bash
echo $ZSH_SOURCED
```

If it's not set to `true`, check the ZSH configuration files for errors.

### Antidote plugins not loading

Ensure antidote is installed and the cache is updated:

```bash
source ${ZDOTDIR:-~}/.antidote/antidote.zsh
antidote update
```

### Starship not showing

Verify starship is installed:

```bash
command -v starship
```

If not found, install it:

```bash
# macOS
brew install starship

# Linux
curl -sS https://starship.rs/install.sh | sh
```

## License

This is personal configuration. Feel free to fork and adapt to your needs.