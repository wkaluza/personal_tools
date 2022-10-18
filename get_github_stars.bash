set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  local page=1
  local result_count=100
  local count_requested=100
  local username="wkaluza"
  local api="https://api.github.com/users/${username}/starred"
  local file=""

  local now
  now="$(date --utc +'%Y%m%d%H%M%S')"
  local token
  token="$(pass show github_cli_access_token_local_pcspec)"

  until [[ "${result_count}" -lt "${count_requested}" ]]; do
    log_info "Fetching page ${page}"

    file="${username}_stars_${page}_${now}.json"

    curl \
      --silent \
      --header "Accept: application/vnd.github.v3+json" \
      --header "Authorization: token ${token}" \
      "${api}?page=${page}&per_page=${count_requested}" |
      jq --sort-keys '.' - >"${file}"

    result_count="$(cat "${file}" |
      jq '. | length' -)"

    page="$((page + 1))"
  done

  log_info "Success: $(basename "$0")"
}

main
