#!/bin/bash
# Simple test runner for dotfiles tests
# This validates the configuration files exist and contain expected content

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASSED=0
FAILED=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

echo "Running dotfiles tests..."
echo ""

# Test ZSH Configuration
echo "Testing ZSH Configuration..."

# Test directory structure
if [[ -d "home/dot_config/zsh" ]]; then
    test_pass "ZSH config directory exists"
else
    test_fail "ZSH config directory missing"
fi

if [[ -f "home/dot_config/zsh/dot_zshrc" ]]; then
    test_pass "ZSH config file exists"
else
    test_fail "ZSH config file missing"
fi

if [[ -f "home/dot_config/zsh/bootstrap.zshrc" ]]; then
    test_pass "Bootstrap file exists"
else
    test_fail "Bootstrap file missing"
fi

if [[ -f "home/dot_config/zsh/aliases.zshrc" ]]; then
    test_pass "Aliases file exists"
else
    test_fail "Aliases file missing"
fi

# Test main zshrc content
if grep -q 'export ZDOTDIR="\$HOME/.config/zsh"' home/dot_zshrc; then
    test_pass "ZDOTDIR exported correctly"
else
    test_fail "ZDOTDIR export missing"
fi

if grep -q 'source "\$ZDOTDIR/.zshrc"' home/dot_zshrc; then
    test_pass "ZDOTDIR config sourced"
else
    test_fail "ZDOTDIR source missing"
fi

if grep -q 'export ZSH_SOURCED=true' home/dot_zshrc; then
    test_pass "ZSH_SOURCED marker set"
else
    test_fail "ZSH_SOURCED marker missing"
fi

# Test bootstrap
if grep -q 'source_file()' home/dot_config/zsh/bootstrap.zshrc; then
    test_pass "source_file function defined"
else
    test_fail "source_file function missing"
fi

if grep -q 'antidote.zsh' home/dot_config/zsh/bootstrap.zshrc; then
    test_pass "Antidote sourced"
else
    test_fail "Antidote source missing"
fi

if grep -q 'antidote load' home/dot_config/zsh/bootstrap.zshrc; then
    test_pass "Antidote loads plugins"
else
    test_fail "Antidote load missing"
fi

if grep -q 'starship' home/dot_config/zsh/bootstrap.zshrc; then
    test_pass "Starship configuration present"
else
    test_fail "Starship config missing"
fi

echo ""
echo "Testing Aliases..."

# Test aliases
if grep -q 'alias v="nvim"' home/dot_config/zsh/aliases.zshrc; then
    test_pass "nvim alias defined"
else
    test_fail "nvim alias missing"
fi

if grep -q 'alias g="git"' home/dot_config/zsh/aliases.zshrc; then
    test_pass "git alias defined"
else
    test_fail "git alias missing"
fi

if grep -q 'alias t="tmux"' home/dot_config/zsh/aliases.zshrc; then
    test_pass "tmux alias defined"
else
    test_fail "tmux alias missing"
fi

if grep -q 'alias lg="lazygit"' home/dot_config/zsh/aliases.zshrc; then
    test_pass "lazygit alias defined"
else
    test_fail "lazygit alias missing"
fi

echo ""
echo "Testing Plugins..."

# Test plugins
if [[ -f "home/dot_config/zsh/dot_zsh_plugins.txt" ]]; then
    test_pass "Plugins file exists"
else
    test_fail "Plugins file missing"
fi

if grep -q 'zsh-users/zsh-autosuggestions' home/dot_config/zsh/dot_zsh_plugins.txt; then
    test_pass "autosuggestions plugin listed"
else
    test_fail "autosuggestions plugin missing"
fi

if grep -q 'zsh-users/zsh-completions' home/dot_config/zsh/dot_zsh_plugins.txt; then
    test_pass "completions plugin listed"
else
    test_fail "completions plugin missing"
fi

if grep -q 'zsh-users/zsh-syntax-highlighting' home/dot_config/zsh/dot_zsh_plugins.txt; then
    test_pass "syntax-highlighting plugin listed"
else
    test_fail "syntax-highlighting plugin missing"
fi

echo ""
echo "Testing Tmux Configuration..."

# Test tmux
if [[ -f "home/dot_config/tmux/tmux.conf" ]]; then
    test_pass "Tmux config exists"
else
    test_fail "Tmux config missing"
fi

if grep -q 'set -g prefix C-s' home/dot_config/tmux/tmux.conf; then
    test_pass "Tmux prefix set to C-s"
else
    test_fail "Tmux prefix not set"
fi

if grep -q 'set -g mouse on' home/dot_config/tmux/tmux.conf; then
    test_pass "Tmux mouse support enabled"
else
    test_fail "Tmux mouse support missing"
fi

if grep -q 'bind-key h select-pane -L' home/dot_config/tmux/tmux.conf; then
    test_pass "Vim-style pane navigation configured"
else
    test_fail "Vim-style navigation missing"
fi

echo ""
echo "Testing Starship Configuration..."

# Test starship
if [[ -f "home/dot_config/starship/starship.toml" ]]; then
    test_pass "Starship config exists"
else
    test_fail "Starship config missing"
fi

if grep -q "palette = 'catppuccin_mocha'" home/dot_config/starship/starship.toml; then
    test_pass "Catppuccin theme configured"
else
    test_fail "Catppuccin theme missing"
fi

if grep -q '\$git_branch' home/dot_config/starship/starship.toml; then
    test_pass "Git branch module included"
else
    test_fail "Git branch module missing"
fi

if grep -q '\$nodejs' home/dot_config/starship/starship.toml; then
    test_pass "Node.js module included"
else
    test_fail "Node.js module missing"
fi

echo ""
echo "Testing Installation Script..."

# Test install script
if [[ -f "home/run_before_01-install-zsh.sh" ]]; then
    test_pass "Install script exists"
else
    test_fail "Install script missing"
fi

if grep -q '#!/bin/sh' home/run_before_01-install-zsh.sh; then
    test_pass "Install script has shebang"
else
    test_fail "Install script shebang missing"
fi

if grep -q 'brew install zsh' home/run_before_01-install-zsh.sh; then
    test_pass "macOS support in install script"
else
    test_fail "macOS support missing"
fi

if grep -q 'apt-get install -y zsh' home/run_before_01-install-zsh.sh; then
    test_pass "Ubuntu support in install script"
else
    test_fail "Ubuntu support missing"
fi

if grep -q 'pacman -S --noconfirm zsh' home/run_before_01-install-zsh.sh; then
    test_pass "Arch support in install script"
else
    test_fail "Arch support missing"
fi

echo ""
echo "================================="
echo -e "Tests: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "================================="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
