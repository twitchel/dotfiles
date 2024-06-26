@test "it can find the path to brew" {
  run which brew
  [ "${status}" -eq 0 ]
  [[ "${output}" =~ "brew" ]]
}