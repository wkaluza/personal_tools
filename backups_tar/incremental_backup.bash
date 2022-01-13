#!/usr/bin/env bash

set -euo pipefail

TEMP_UNPACK_DIR="$HOME/not_a_real_directory"
TEMP_SNAPSHOT_FILE="$HOME/not_a_real_file"

function on_exit
{
  rm -rf "${TEMP_UNPACK_DIR}"
  rm -f "${TEMP_SNAPSHOT_FILE}"
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

  local snapshot_file
  snapshot_file="$(find "${backup_dir}" -type f -name 'tar_snapshot_*')"
  if test -f "${snapshot_file}"; then
    snapshot_file="$(realpath "${snapshot_file}")"
    TEMP_SNAPSHOT_FILE="$(dirname "${snapshot_file}")/temp_snapshot"
    cp "${snapshot_file}" "${TEMP_SNAPSHOT_FILE}"
  else
    echo No snapshot file: perfoming initial full backup...
    snapshot_file="${backup_dir}/tar_snapshot_${now}"
  fi

  tar \
    --directory "$(dirname "${dir_to_back_up}")" \
    --listed-incremental="${snapshot_file}" \
    --create \
    --gzip \
    --file "${backup_dir}/backup_${now}.tar.gz" \
    "./$(basename "${dir_to_back_up}")"

  TEMP_UNPACK_DIR="$(dirname "${backup_dir}")/temp_unpack_$(basename "${backup_dir}")"
  mkdir --parents "${TEMP_UNPACK_DIR}"

  echo "Performing test restoration..."

  for f in $(find "${backup_dir}" -type f -name 'backup_*.tar.gz' | sort); do
    echo "  Extracting $(realpath "${f}")"

    tar \
      --directory "${TEMP_UNPACK_DIR}" \
      --listed-incremental=/dev/null \
      --extract \
      --gzip \
      --file "$(realpath "${f}")"
  done

  echo "Test restoration done"
  echo "Performing comparison..."

  if ! diff --recursive "${TEMP_UNPACK_DIR}/$(basename "${dir_to_back_up}")" "${dir_to_back_up}"; then
    echo "Test recovery failed: diff did not match with original"
    rm "${backup_dir}/backup_${now}.tar.gz"
    if test -f "${TEMP_SNAPSHOT_FILE}"; then
      mv -f "${TEMP_SNAPSHOT_FILE}" "${snapshot_file}"
    fi

    exit 1
  fi

  echo Success
}

# Entry point
main "$1" "$2"
