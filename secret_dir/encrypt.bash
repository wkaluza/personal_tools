set -euo pipefail

function main
{
  local secret_dir
  secret_dir="$(realpath "$1")"

  local primary_key="174C9368811039C87F0C806A896572D1E78ED6A7"
  local encryption_subkey="217BB178444E212F714DBAC90FBB9BD0E486C169"
  local encrypted_file
  encrypted_file="$(basename "${secret_dir}")_gpg_${encryption_subkey}_$(date --utc +'%Y%m%d%H%M%S').secret"

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
main "$1"
