set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function common_import_fn
{
  echo "common_import_fn called"
}
