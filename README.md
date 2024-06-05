# dotfiles

Shared dotfiles between machines, managed by [`chezmoi`](https://github.com/twpayne/chezmoi).

## Supported operating systems
This is my standard set of applications + configuration and is designed to run on my OS's of choice.

This has been tested on:
- MacOS (Sonoma+)
- Ubuntu Linux 24.04+
- Windows 11 (WSL with Ubuntu 24.04)

It also has had limited testing on Android using the [Termux app located on F-Droid](https://f-droid.org/en/packages/com.termux/).

## Install

Install everything with:

### curl
```
sh -c "$(curl -fsLS https://raw.githubusercontent.com/twitchel/dotfiles/master/install.sh)"
```

### wget
```
sh -c "$(wget -qO- https://raw.githubusercontent.com/twitchel/dotfiles/master/install.sh)"
```

There are some config flags you can set via environment variables
```
DOTFILES_BRANCH=feature/git-branch-for-testing
DOTFILES_DEBUG=true
DOTFILES_VERBOSE=true
```

You will need to restart your terminal session afterwards

