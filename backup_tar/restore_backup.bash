set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function main
{
  local restore_destination
  restore_destination="$(realpath "$1")"
  local backup_dir
  backup_dir="$(realpath "$2")"

  mkdir --parents "${restore_destination}"

  if ! test -z "$(ls -A "${restore_destination}")"; then
    log_error "${restore_destination} is not empty"
    exit 1
  fi

  mkdir --parents "${backup_dir}"

  log_info "Performing restoration..."

  for f in $(find "${backup_dir}" -type f -name '*_backup.secret' | sort); do
    log_info "- Extracting $(realpath "${f}")"

    cat "$(realpath "${f}")" |
      gpg \
        --decrypt \
        --quiet |
      tar \
        --directory "${restore_destination}" \
        --listed-incremental=/dev/null \
        --extract \
        --gzip
  done

  log_info "Success $(basename "$0")"
}

main "$1" "$2"
