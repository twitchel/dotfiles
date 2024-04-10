# dotfiles

Shared dotfiles between machines, managed by [`chezmoi`](https://github.com/twpayne/chezmoi).

Install them with:

    chezmoi init twitchel

Personal secrets are stored in [1Password](https://1password.com) and you'll
need the [1Password CLI](https://developer.1password.com/docs/cli/) installed.
Login to 1Password with:

    eval $(op signin)
