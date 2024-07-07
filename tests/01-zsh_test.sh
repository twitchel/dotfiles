#!/usr/bin/env zsh

testShellIsZsh() {
  shellCheck=`echo $0`
  assertContains  "${shellCheck}" "zsh"
}

. shunit2