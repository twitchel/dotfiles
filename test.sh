#!/usr/bin/env zsh

exitCode=0

for FILE in tests/*; do
  sh $FILE;
  if [[ $? -ne 0 ]]; then
    echo "item has failed"
    exitCode=1
  fi
done

exit $exitCode
