#!/usr/bin/env zsh

hasFailed=false

for FILE in tests/*; do
  sh $FILE;
  if [ $? -ne 0 ]; then
    hasFailed=true
  fi
done

if [ $hasFailed == 'true' ]; then
  exit 1;
fi

exit 0