set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function pass_store
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

  if ! pass_exists "${id}" &>/dev/null; then
    pass_generate \
      "${id}" \
      "${how_long}" &>/dev/null
  fi

  pass_show "${id}"
}

function pass_exists
{
  local id="$1"

  if ! pass ls |
    tail -n+2 |
    sed -E 's|^....||' |
    grep -E '^[a-zA-Z]' |
    grep -E "^${id}$" &>/dev/null; then
    return 1
  fi
}

function pass_show
{
  local id="$1"

  pass show "${id}"
}

function pass_generate
{
  local id="$1"
  local how_long="${2:-"32"}"

  random_bytes "${how_long}" |
    hex |
    pass_store "${id}"
}
