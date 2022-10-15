set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function root_import_fn
{
  echo "root_import_fn called"
}
