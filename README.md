# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/) for a consistent development environment across multiple systems.

## Overview

This repository contains configuration files for:
- **ZSH**: Shell configuration with antidote plugin manager and starship prompt
- **Tmux**: Terminal multiplexer configuration
- **Git**: Version control settings
- **Homebrew**: Package management for macOS and Linux
- **Various CLI tools**: neovim, lazygit, and more

## Requirements

A running system with the following installed:
- [chezmoi](https://www.chezmoi.io/) - Dotfile manager
- git - Version control

## Supported Operating Systems
- macOS (Tahoe)
- Fedora Workstation
- Fedora Silverblue

## Installation

### Quick Install

```bash
# Clone this repository
git clone https://github.com/twitchel/dotfiles.git
cd dotfiles

# Install chezmoi if not already installed
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize and apply dotfiles
chezmoi init --source "$(pwd)" --no-tty
chezmoi apply --source "$(pwd)" --no-tty
```

### Manual Install

1. Install chezmoi following the [official guide](https://www.chezmoi.io/install/)
2. Clone this repository to your preferred location
3. Run `chezmoi init --source /path/to/dotfiles`
4. Review changes with `chezmoi diff`
5. Apply dotfiles with `chezmoi apply`

## Project Structure

```
.
├── home/                      # Chezmoi source files
│   ├── .chezmoiscripts/      # Installation scripts
│   ├── .chezmoitemplates/    # Template files
│   ├── dot_config/           # XDG config files
│   │   ├── zsh/             # ZSH configuration
│   │   ├── tmux/            # Tmux configuration
│   │   ├── brew/            # Homebrew bundles
│   │   └── starship/        # Starship prompt config
│   └── dot_zshrc            # Main ZSH entry point
├── scripts/                  # Utility scripts
│   └── ci/                  # CI-specific scripts
├── tests/                    # Test files (zunit)
└── .github/                  # GitHub Actions workflows
```

## Testing

Tests are written using [zsh-zunit](https://github.com/zunit-zsh/zunit) and can be run locally or in CI.

### Running Tests Locally

```bash
# Install zunit
git clone https://github.com/zunit-zsh/zunit.git /tmp/zunit
export PATH="/tmp/zunit:$PATH"

# Run all tests
cd tests
zunit --verbose

# Run specific test file
zunit bootstrap_test.zunit
```

### Continuous Integration

Tests run automatically on pull requests via GitHub Actions. The workflow:
1. Checks out the repository
2. Installs chezmoi and applies dotfiles
3. Installs zsh and zunit
4. Runs all tests in the `tests/` directory
5. **Generates test reports** with:
   - Summary comment posted on the PR
   - Test results in GitHub Actions job summary
   - Downloadable test artifacts (TAP format, logs, reports)

For more details on test reporting, see [docs/TEST-REPORTING.md](docs/TEST-REPORTING.md).

## Development

### Adding New Configurations

1. Add your configuration files to the appropriate location in `home/`
2. Use chezmoi naming conventions:
   - `dot_` prefix for dotfiles (e.g., `dot_zshrc` → `~/.zshrc`)
   - `dot_config/` for XDG config directory files
3. Test locally with `chezmoi apply --dry-run --verbose`

### Adding Tests

1. Create a new test file in `tests/` with `.zunit` extension
2. Follow the zunit test syntax:
   ```zsh
   #!/usr/bin/env zunit
   
   @test 'Description of test' {
     # Test code here
     assert $something same_as 'expected'
   }
   ```
3. Make the test file executable: `chmod +x tests/your_test.zunit`
4. Run tests to verify: `zunit tests/your_test.zunit`

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `cd tests && zunit --verbose`
6. Commit your changes: `git commit -am 'Add some feature'`
7. Push to the branch: `git push origin feature/your-feature`
8. Submit a pull request

## License

This repository is for personal use. Feel free to fork and adapt for your own needs.