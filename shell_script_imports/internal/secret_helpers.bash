set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function pass_store
{
  local id="$1"

  cat - |
    pass insert \
      --force \
      --multiline \
      "${id}" &>/dev/null
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

function pass_generate_if_absent
{
  local id="$1"

  if ! pass_exists "${id}"; then
    pass_generate \
      "${id}"
  fi
}

function pass_store_if_absent
{
  local id="$1"

  if ! pass_exists "${id}"; then
    pass_store \
      "${id}"
  fi
}
