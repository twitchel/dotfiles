#!/usr/bin/env bash

echo "⭐️ Running after 999 post-run"

cat <<EOF
✅  Chezmoi complete!

🚀  Next steps:
  - If this is your first time running chezmoi:
    - Review the generated files in your home directory to ensure they are correct
    - Restart your terminal to apply any changes to your shell configuration
  - Pull latest shell config using "source ~/.zshrc" or restart your terminal
  - Run 'brewup' install/update packages. This has been tailored to your system.

ℹ️  Working with Chezmoi commands:
  - Run 'chezmoi update' to pull the latest changes from source
  - Run 'chezmoi cd' to change to the source directory
  - Run 'chezmoi init --prompt' to rebuild the chezmoi configuration

📚  For more information, visit: https://www.chezmoi.io/docs/quick-start/
EOF