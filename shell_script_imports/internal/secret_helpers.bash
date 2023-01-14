set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function store_in_pass
{
  local id="$1"

  cat - |
    quiet pass insert \
      --force \
      --multiline \
      "${id}"
}

function pass_show_or_generate
{
  local id="$1"
  local how_long="${2:-"32"}"

  if ! pass show "${id}" &>/dev/null; then
    random_bytes "${how_long}" |
      hex |
      store_in_pass "${id}"
  fi

  pass show "${id}"
}
