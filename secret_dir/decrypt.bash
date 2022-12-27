set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function main
{
  local encrypted_file
  encrypted_file="$(realpath "$1")"
  local target_dir
  target_dir="$(realpath "$2")"

  if ! test -f "${encrypted_file}"; then
    echo "File ${encrypted_file} does not exist"
  fi

  mkdir --parents "${target_dir}"

  quiet pushd "${target_dir}"
  cat "${encrypted_file}" |
    gpg \
      --verbose \
      --decrypt |
    tar -xzv .
  quiet popd
}

# Entry point
main "$1" "$2"
