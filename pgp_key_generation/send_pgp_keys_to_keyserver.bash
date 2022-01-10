#!/usr/bin/env bash

set -euo pipefail

function main
{
  local primary_key_fingerprint="$1"

  gpg --keyserver keys.openpgp.org --send-keys "${primary_key_fingerprint}"
  gpg --keyserver pgp.mit.edu --send-keys "${primary_key_fingerprint}"
  gpg --keyserver keyserver.ubuntu.com --send-keys "${primary_key_fingerprint}"
}

# Entry point
main "$1"
