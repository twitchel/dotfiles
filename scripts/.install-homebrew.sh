printf "\e[1;33mBootstrap\e[0m\n"

	type brew >/dev/null 2>&1 && printf "Brew already installed" && exit

printf "Installing Brew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
