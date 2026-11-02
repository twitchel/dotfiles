#!/usr/bin/env bats

load '../helpers/common'

@test "chezmoidata.yaml is valid YAML" {
  run yq eval '.' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
}

@test "hostData.default exists" {
  run yq eval '.hostData.default' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
  [ "$output" != "null" ]
}

@test "hostData.default.defaultShell is zsh" {
  run yq eval '.hostData.default.defaultShell' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
  [ "$output" = "zsh" ]
}

@test "hostData.default.packages.brew is non-empty" {
  run yq eval '.hostData.default.packages.brew | length' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
}

@test "known hosts exist in hostData" {
  for host in coffee-sponge grease-monkey dj-10xlabs ci; do
    run yq eval ".hostData.\"${host}\" | has(\"packages\")" "${CHEZMOIDATA}"
    [ "$output" = "true" ]
  done
}

@test "coffee-sponge has rpmOstree packages" {
  run yq eval '.hostData.coffee-sponge.packages.rpmOstree | length' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
}

@test "coffee-sponge has ublue-os/tap in brewCaskTaps" {
  run yq eval '.hostData.coffee-sponge.packages.brewCaskTaps[] | select(. == "ublue-os/tap")' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
  [ "$output" = "ublue-os/tap" ]
}

@test "grease-monkey flatpak is an empty list not null" {
  run yq eval '.hostData.grease-monkey.packages.flatpak' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "dj-10xlabs has its extra brewCask apps" {
  for app in claude-code google-chrome slack; do
    run yq eval ".hostData.dj-10xlabs.packages.brewCask[] | select(. == \"${app}\")" "${CHEZMOIDATA}"
    [ "$status" -eq 0 ]
    [ "$output" = "$app" ]
  done
}

@test "unknown hostname returns empty host-specific package lists (nil guard)" {
  # Verifies the nil guard: get .hostData .hostname returns nil for unknown hosts;
  # templates must not error when hostname is not in hostData.
  run yq eval '.hostData | has("unknown-host-xyz")' "${CHEZMOIDATA}"
  [ "$output" = "false" ]
}

@test "default brewTaps are all strings" {
  run yq eval '.hostData.default.packages.brewTaps[] | type' "${CHEZMOIDATA}"
  [ "$status" -eq 0 ]
  while IFS= read -r line; do
    [ "$line" = "!!str" ]
  done <<< "$output"
}

@test "node is in default brew packages" {
  run yq eval '.hostData.default.packages.brew[] | select(. == "node")' "${CHEZMOIDATA}"
  [ "$output" = "node" ]
}
