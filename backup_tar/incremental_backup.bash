set -euo pipefail
shopt -s inherit_errexit

TEMP_UNPACK_DIR="$HOME/not_a_real_directory"

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"

function on_exit
{
  rm -rf "${TEMP_UNPACK_DIR}"
}

trap on_exit EXIT

function main
{
  local primary_key="174C9368811039C87F0C806A896572D1E78ED6A7"
  local encryption_subkey="217BB178444E212F714DBAC90FBB9BD0E486C169"

  local dir_to_back_up
  dir_to_back_up="$(realpath "$1")"
  local backup_dir
  backup_dir="$(realpath "$2")"

  if ! test -d "${dir_to_back_up}"; then
    log_error "${dir_to_back_up} is not a directory"
    exit 1
  fi

  mkdir --parents "${backup_dir}"

  local now
  now="$(date --utc +'%Y%m%d%H%M%S%N')"

  local last_snapshot_file
  last_snapshot_file="$(find "${backup_dir}" -type f -name '*_snapshot.secret' | sort | tail -n1)"

  local snapshot_file
  snapshot_file="$(realpath "${backup_dir}/${now}_gpg_${encryption_subkey}_snapshot.secret")"

  if test -f "${last_snapshot_file}"; then
    cat "${last_snapshot_file}" |
      gpg \
        --decrypt \
        --quiet >"${snapshot_file}.decrypted"
  else
    log_info "No snapshot file: performing initial full backup..."
  fi

  tar \
    --directory "$(dirname "${dir_to_back_up}")" \
    --listed-incremental="${snapshot_file}.decrypted" \
    --create \
    --gzip \
    --exclude '*/.idea*' \
    --exclude '*/node_modules*' \
    "./$(basename "${dir_to_back_up}")" |
    gpg \
      --encrypt \
      --recipient "${primary_key}" \
      --output "${backup_dir}/${now}_gpg_${encryption_subkey}_backup.secret"

  cat "${snapshot_file}.decrypted" |
    gpg \
      --encrypt \
      --recipient "${primary_key}" \
      --output "${snapshot_file}"

  rm "${snapshot_file}.decrypted"

  TEMP_UNPACK_DIR="$(dirname "${backup_dir}")/temp_unpack_$(basename "${backup_dir}")"
  mkdir --parents "${TEMP_UNPACK_DIR}"

  log_info "Performing test restoration..."

  for f in $(find "${backup_dir}" -type f -name '*_backup.secret' | sort); do
    log_info "- Extracting $(realpath "${f}")"

    cat "$(realpath "${f}")" |
      gpg \
        --decrypt \
        --quiet |
      tar \
        --directory "${TEMP_UNPACK_DIR}" \
        --listed-incremental=/dev/null \
        --extract \
        --gzip
  done

  log_info "Test restoration done"
  log_info "Performing comparison..."

  if ! diff \
    --recursive \
    --no-dereference \
    --exclude '.idea' \
    --exclude 'node_modules' \
    "${TEMP_UNPACK_DIR}/$(basename "${dir_to_back_up}")" \
    "${dir_to_back_up}"; then
    log_error "Test recovery failed: diff did not match with original"

    rm "${backup_dir}/${now}_gpg_${encryption_subkey}_backup.secret"
    rm "${snapshot_file}"

    exit 1
  fi

  log_info "Success: $(basename "$0")"
}

# Entry point
main "$1" "$2"
