# Dotfiles Tests

This directory contains automated tests for the dotfiles configuration. The tests validate that all configuration files exist in the correct locations and contain the expected content.

## Prerequisites

- Bash (already available on most systems)
- Standard Unix utilities (grep, test)

## Running Tests

To run all tests:

```bash
# From the repository root
./tests/run_tests.sh

# Or from the tests directory
cd tests
./run_tests.sh
```

The test runner will:
1. Check that all configuration files exist
2. Validate configuration content
3. Verify all required settings are present
4. Report pass/fail status for each test

## Test Files

The repository includes both a bash test runner and zunit test files:

### Bash Test Runner (Primary)
- **run_tests.sh** - Main test runner that validates all dotfiles

### ZUnit Test Files (Optional)
If you have [zunit](https://zunit.xyz/) installed, you can also run:
- **zshrc.zunit** - Tests for the main ZSH configuration structure
- **aliases.zunit** - Tests for command aliases
- **plugins.zunit** - Tests for ZSH plugin configuration
- **tmux.zunit** - Tests for tmux configuration
- **starship.zunit** - Tests for starship prompt configuration
- **install.zunit** - Tests for the ZSH installation script

To use zunit:
```bash
# Install zunit first (requires zsh)
npm install -g zunit
# Or using Homebrew on macOS
brew tap zunit-zsh/zunit
brew install zunit

# Run zunit tests
zunit tests
```

## Test Coverage

The tests validate:

1. **Configuration Structure**
   - Files and directories exist in the correct locations
   - Configuration files are properly formatted

2. **ZSH Setup**
   - ZDOTDIR is correctly exported
   - Bootstrap functions are defined
   - Plugins are loaded via antidote
   - Starship integration is configured
   - ZSH_SOURCED marker is set

3. **Aliases**
   - All expected aliases are defined (nvim, git, tmux, lazygit, etc.)
   - Alias syntax is correct

4. **Plugins**
   - Required plugins are listed (autosuggestions, completions, syntax-highlighting)
   - Plugin configuration file is valid

5. **Tmux Configuration**
   - Prefix key is correctly set to Ctrl+s
   - Vim-style navigation is configured
   - Plugins are loaded
   - Mouse support is enabled

6. **Starship Configuration**
   - Catppuccin Mocha theme is applied
   - Required modules are included (git, directory, time, programming languages)
   - OS symbols are configured

7. **Installation Scripts**
   - Multi-platform support (macOS, Ubuntu, Arch/Manjaro)
   - Proper error handling
   - Package manager detection

## Example Output

```
Running dotfiles tests...

Testing ZSH Configuration...
✓ ZSH config directory exists
✓ ZSH config file exists
✓ Bootstrap file exists
✓ Aliases file exists
✓ ZDOTDIR exported correctly
✓ ZDOTDIR config sourced
✓ ZSH_SOURCED marker set

Testing Aliases...
✓ nvim alias defined
✓ git alias defined
✓ tmux alias defined
✓ lazygit alias defined

...

=================================
Tests: 32 passed, 0 failed
=================================
```
