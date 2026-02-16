# Tests

This directory contains tests for the dotfiles repository using [zsh-zunit](https://github.com/zunit-zsh/zunit).

## Test Files

- **aliases_test.zunit** - Tests for shell aliases defined in `home/dot_config/zsh/aliases.zshrc`
- **bootstrap_test.zunit** - Tests for the `source_file` function from `home/dot_config/zsh/bootstrap.zshrc.tmpl`
- **zshrc_test.zunit** - Tests for the main `.zshrc` file and environment setup

## Running Tests

### Locally

```bash
# Install zunit and its dependency revolver
git clone https://github.com/molovo/revolver.git /tmp/revolver
git clone https://github.com/zunit-zsh/zunit.git /tmp/zunit
cd /tmp/zunit && ./build.zsh

# Add to PATH
export PATH="/tmp/zunit:/tmp/revolver:$PATH"

# Run all tests
cd /path/to/dotfiles
zunit --verbose tests

# Run specific test file
zunit --verbose tests/aliases_test.zunit
```

### In CI

Tests run automatically in GitHub Actions on every pull request. See `.github/workflows/pull-request.yml` for the configuration.

## Test Coverage

The tests verify:
- ZSH configuration loads correctly
- Environment variables are set properly (ZSH_SOURCED, ZDOTDIR)
- The `source_file` helper function works as expected
- Shell aliases are defined correctly
