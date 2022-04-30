set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local secret_dir
  secret_dir="$(realpath "$1")"
  local target_dir
  target_dir="$(realpath "$2")"

  local now
  now="$(date --utc +'%Y%m%d%H%M%S%N')"

  local primary_key="174C9368811039C87F0C806A896572D1E78ED6A7"
  local encryption_subkey="217BB178444E212F714DBAC90FBB9BD0E486C169"
  local encrypted_file
  encrypted_file="${target_dir}/$(basename "${secret_dir}")_gpg_${encryption_subkey}_${now}.secret"

  if test -f "${encrypted_file}"; then
    echo "Output file already exists, aborting..."
    exit 1
  fi

  if ! test -d "${secret_dir}"; then
    echo "Directory does not exist, aborting..."
    exit 1
  fi

  mkdir --parents "$(dirname "${encrypted_file}")"

  tar \
    -C "$(dirname "${secret_dir}")" \
    -cz \
    "./$(basename "${secret_dir}")" |
    gpg \
      --verbose \
      --armor \
      --encrypt \
      --recipient "${primary_key}" \
      --output "${encrypted_file}"

  chmod 400 "${encrypted_file}"
}

# Entry point
main "$1" "$2"
