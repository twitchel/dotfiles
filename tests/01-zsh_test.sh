#!/usr/bin/env zsh

testShellIsZsh() {
  shellCheck=`echo $SHELL`
  assertContains  "${shellCheck}" "zsh"
}

. shunit2