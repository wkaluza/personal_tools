set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/common.bash"
source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"

source <(cat "${THIS_SCRIPT_DIR}/local_domains.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '. | .[]' - |
  sort)

CONTENT_TYPE_APP_JSON="Content-Type: application/json"
REMOTE_NAME="gogs"
USERNAME="wkaluza"
V1_API="https://${DOMAIN_GIT_FRONTEND_df29c969}/api/v1"

function add_git_remote
{
  local repo_name="$1"

  git remote add \
    "${REMOTE_NAME}" \
    "git@${DOMAIN_GIT_FRONTEND_df29c969}:${USERNAME}/${repo_name}.git"
}

function check_repo_exists
{
  local repo_name="$1"
  local auth_header="$2"

  curl \
    --fail \
    --header "${auth_header}" \
    --header "${CONTENT_TYPE_APP_JSON}" \
    --show-error \
    --silent \
    "${V1_API}/repos/${USERNAME}/${repo_name}/branches"
}

function create_repo
{
  local repo_name="$1"
  local description="$2"
  local auth_header="$3"

  local create_data
  create_data="$(echo '{}' |
    jq ". + {name: \"${repo_name}\"}" - |
    jq '. + {private: true}' - |
    jq ". + {description: \"${description}\"}" - |
    jq --compact-output --sort-keys '.' -)"

  curl \
    --data "${create_data}" \
    --fail \
    --header "${auth_header}" \
    --header "${CONTENT_TYPE_APP_JSON}" \
    --show-error \
    --silent \
    "${V1_API}/admin/users/${USERNAME}/repos"
}

function check_webhook_exists
{
  local auth_header="$1"
  local repo_name="$2"

  curl \
    --fail \
    --header "${auth_header}" \
    --header "${CONTENT_TYPE_APP_JSON}" \
    --request "GET" \
    --show-error \
    --silent \
    "${V1_API}/repos/${USERNAME}/${repo_name}/hooks" |
    jq --sort-keys 'if . | length > 0 then . else error("No webhooks found") end' -
}

function create_webhook
{
  local auth_header="$1"
  local repo_name="$2"

  local webhook_config
  webhook_config="$(echo '{}' |
    jq ". + {url: \"https://${DOMAIN_WEBHOOK_SINK_a8800f5b}/gogs\"}" - |
    jq ". + {content_type: \"json\"}" - |
    jq ". + {secret: \"$(pass_show_or_generate "local_gogs_webhook_secret")\"}" - |
    jq --compact-output --sort-keys '.' -)"

  # Also supported: "fork","issues","issue_comment","release"
  local events='"create","delete","pull_request","push"'
  local webhook_data
  webhook_data="$(echo '{}' |
    jq ". + {type: \"gogs\"}" - |
    jq ". + {config: ${webhook_config}}" - |
    jq ". + {events: [${events}]}" - |
    jq '. + {active: true}' - |
    jq --compact-output --sort-keys '.' -)"

  curl \
    --data "${webhook_data}" \
    --fail \
    --header "${auth_header}" \
    --header "${CONTENT_TYPE_APP_JSON}" \
    --request "POST" \
    --show-error \
    --silent \
    "${V1_API}/repos/${USERNAME}/${repo_name}/hooks"
}

function perform_fetch
{
  git fetch \
    --all \
    --force \
    --recurse-submodules \
    --tags
}

function perform_push
{
  git push \
    --all \
    --force \
    --repo "${REMOTE_NAME}" \
    --set-upstream

  git push \
    --force \
    --repo "${REMOTE_NAME}" \
    --tags
}

function main
{
  local current_repo_directory
  current_repo_directory="$(realpath "$1")"

  pushd "${current_repo_directory}" >/dev/null

  local repo_name
  repo_name="$(basename "${current_repo_directory}")"

  log_info "Adding remote..."
  add_git_remote \
    "${repo_name}" >/dev/null 2>&1 ||
    true

  local description="placeholder description"

  local token
  token="$(pass show "local_gogs_token_${USERNAME}")"
  auth_header="Authorization: token ${token}"

  if ! check_repo_exists \
    "${repo_name}" \
    "${auth_header}" >/dev/null 2>&1; then
    log_info "Creating gogs repository..."
    create_repo \
      "${repo_name}" \
      "${description}" \
      "${auth_header}" >/dev/null 2>&1
  fi

  if ! check_webhook_exists \
    "${auth_header}" \
    "${repo_name}" >/dev/null; then
    log_info "Adding webhook..."
    create_webhook \
      "${auth_header}" \
      "${repo_name}" >/dev/null
  fi

  log_info "Fetching..."
  perform_fetch >/dev/null 2>&1

  log_info "Pushing branches and tags..."
  perform_push >/dev/null 2>&1

  popd >/dev/null

  log_info "Success: $(basename "$0")"
}

main "$1"
