set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function unstar
{
  local token="$1"
  local starred_repo="$2"

  local api="https://api.github.com/user/starred"

  log_info "Unstarring ${starred_repo}..."

  curl \
    --header "Authorization: token ${token}" \
    --request "DELETE" \
    --silent \
    "${api}/${starred_repo}"
}

function get_starred_repos
{
  local token="$1"

  local page=1
  local result_count=100
  local count_requested=100
  local username="wkaluza"
  local api="https://api.github.com/users/${username}/starred"
  local data
  local file
  file="$(mktemp)"

  until [[ "${result_count}" -lt "${count_requested}" ]]; do
    data="$(curl \
      --header "Accept: application/vnd.github.v3+json" \
      --header "Authorization: token ${token}" \
      --silent \
      "${api}?page=${page}&per_page=${count_requested}" |
      jq '.' -)"

    result_count="$(echo "${data}" |
      jq '. | length' -)"

    echo "${data}" | jq --raw-output '.[].full_name' >>"${file}"

    page="$((page + 1))"
  done

  cat "${file}" | sort
}

function main
{
  local token
  token="$(pass_show github_cli_access_token_local_pcspec)"

  get_starred_repos "${token}" |
    for_each unstar "${token}"

  log_info "Success: $(basename "$0")"
}

main
