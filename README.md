# dotfiles

Shared dotfiles between machines, managed by [`chezmoi`](https://github.com/twpayne/chezmoi).

# Base Chezmoi Requirements

1. Install base OS level dependencies (Ubuntu + Debian flavours).

I use Ubuntu as my distribution of choice, so these commands are tailored for that. They should work for any debian based linux distribution, and should be fairly easily converted to work when RHEL/Other based distros.

```
sudo apt-get install -y curl git gcc build-essentials
```

# Install

Install everything with:

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply twitchel
```

You will need to restart your terminal session afterwards

# Secrets

Personal secrets are stored in [1Password](https://1password.com) and you'll
need the [1Password CLI](https://developer.1password.com/docs/cli/) installed.
Login to 1Password with:

    eval $(op signin)
