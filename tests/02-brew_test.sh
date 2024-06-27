#!/usr/bin/env zsh

testBrewIsInstalled() {
  brewCheck=`which brew`
  assertContains  "${brewCheck}" "brew"
}

. shunit2