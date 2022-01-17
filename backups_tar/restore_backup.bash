#!/usr/bin/env bash

set -euo pipefail

function main
{
  local restore_destination
  restore_destination="$(realpath "$1")"
  local backup_dir
  backup_dir="$(realpath "$2")"

  mkdir --parents "${restore_destination}"

  if ! test -z "$(ls -A "${restore_destination}")"; then
    echo "${restore_destination} is not empty"
    exit 1
  fi

  mkdir --parents "${backup_dir}"

  echo "Performing restoration..."

  for f in $(find "${backup_dir}" -type f -name '*_backup.tar.gz' | sort); do
    echo "- - Extracting $(realpath "${f}")"

    tar \
      --directory "${restore_destination}" \
      --listed-incremental=/dev/null \
      --extract \
      --gzip \
      --file "$(realpath "${f}")"
  done

  echo Success
}

# Entry point
main "$1" "$2"
