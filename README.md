# dotfiles

Shared dotfiles between machines, managed by [`chezmoi`](https://github.com/twpayne/chezmoi).

## Why?
I'm building this repository in order to create a consistent shell environment on whichever machine i may be using. I'm currently learning to use vim so that I can be productive no-matter the environment/machine im currently working on.

My pipedream is to be able to work off an Android tablet for the ultimate ultra-light dev setup.

## Supported operating systems
This is my standard set of applications + configuration and is designed to run on my OS's of choice.

This has been tested on:
- MacOS (Sonoma+)
- Ubuntu Linux 24.04+
- Windows 11 (WSL with Ubuntu 24.04)

It also has had limited testing on Android using the [Termux app located on F-Droid](https://f-droid.org/en/packages/com.termux/). This is still not in a working state as of yet however.

## Dependencies
While the dotfiles repo is designed to be a one-command install, there are a few dependencies that must be setup first

If running on Linux you will need to install the following packages:
- `zsh` - should be installed and set as your default shell.
- `git` - for cloning the repo
- `curl` or `wget` - for downloading the install script

If running on a Mac you will need to install the Xcode command line tools
```
xcode-select --install
```

If running on Windows you will need to install WSL and Ubuntu 24.04. You will also need to install the following packages:
- `zsh`
- `git`
- `curl` or `wget`

Finally, if running on Android, you will need to install the Termux app from F-Droid. You will also need to install the following packages:
- `zsh`
- `git`
- `curl` or `wget`

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

