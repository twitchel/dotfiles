@test "it has set the default shell to zsh" {
  run echo $SHELL
  [ "${status}" -eq 0 ]
  [[ "${output}" =~ "zsh" ]]
}