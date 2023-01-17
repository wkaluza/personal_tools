set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

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

  log_info "Success $(basename "$0")"
}

main "$1" "$2"
