set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function user_import_fn
{
  echo "user_import_fn called"
}
