#!/usr/bin/env bash

set -euo pipefail

TEMP_UNPACK_DIR="$HOME/not_a_real_directory"

function on_exit
{
  rm -rf "${TEMP_UNPACK_DIR}"
}

trap on_exit EXIT

function main
{
  local dir_to_back_up
  dir_to_back_up="$(realpath "$1")"
  local backup_dir
  backup_dir="$(realpath "$2")"

  if ! test -d "${dir_to_back_up}"; then
    echo "${dir_to_back_up} is not a directory"
    exit 1
  fi

  mkdir --parents "${backup_dir}"

  local now
  now="$(date --utc +'%Y%m%d%H%M%S%N')"

  local last_snapshot_file
  last_snapshot_file="$(find "${backup_dir}" -type f -name 'tar_snapshot_*' | sort | tail -n1)"

  local snapshot_file
  snapshot_file="$(realpath "${backup_dir}/tar_snapshot_${now}")"

  if test -f "${last_snapshot_file}"; then
    cp "${last_snapshot_file}" "${snapshot_file}"
  else
    echo No snapshot file: perfoming initial full backup...
  fi

  tar \
    --directory "$(dirname "${dir_to_back_up}")" \
    --listed-incremental="${snapshot_file}" \
    --create \
    --gzip \
    --verbose \
    --file "${backup_dir}/backup_${now}.tar.gz" \
    "./$(basename "${dir_to_back_up}")"

  TEMP_UNPACK_DIR="$(dirname "${backup_dir}")/temp_unpack_$(basename "${backup_dir}")"
  mkdir --parents "${TEMP_UNPACK_DIR}"

  echo "Performing test restoration..."

  for f in $(find "${backup_dir}" -type f -name 'backup_*.tar.gz' | sort); do
    echo "- - Extracting $(realpath "${f}")"

    tar \
      --directory "${TEMP_UNPACK_DIR}" \
      --listed-incremental=/dev/null \
      --extract \
      --gzip \
      --file "$(realpath "${f}")"
  done

  echo "Test restoration done"
  echo "Performing comparison..."

  if ! diff \
    --recursive \
    --no-dereference \
    "${TEMP_UNPACK_DIR}/$(basename "${dir_to_back_up}")" \
    "${dir_to_back_up}"; then
    echo "Test recovery failed: diff did not match with original"

    rm "${backup_dir}/backup_${now}.tar.gz"
    rm "${snapshot_file}"

    exit 1
  fi

  echo Success
}

# Entry point
main "$1" "$2"
