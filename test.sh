#!/usr/bin/env zsh

exitCode=0

echo "Prepping Tests"
echo "Running as user: $(whoami)"
echo "Running in shell: $(echo $0)"
echo "Running in dir: $(pwd)"
echo "Sourcing zshrc"
source $HOME/.zshrc

for FILE in tests/*; do
  sh $FILE;
  if [[ $? -ne 0 ]]; then
    echo "item has failed"
    exitCode=1
  fi
done

exit $exitCode
