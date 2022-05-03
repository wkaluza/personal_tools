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

function main
{
  local current_repo_directory
  current_repo_directory="$(realpath "$1")"

  pushd "${current_repo_directory}" >/dev/null

  local remote_name="gogs"
  local username="wkaluza"
  local repo_name
  repo_name="$(basename "${current_repo_directory}")"

  log_info "Adding remote..."
  git remote add \
    "${remote_name}" \
    "git@${GIT_FRONTEND_HOST_df29c969}:${username}/${repo_name}.git"

  local description="placeholder description"
  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${GIT_FRONTEND_HOST_df29c969}/api/v1"

  local password
  password="$(pass show "local_gogs_password_${username}")"
  local token
  token="$(pass show "local_gogs_token_${username}")"
  auth_header="Authorization: token ${token}"

  local create_data
  create_data="$(echo '{}' |
    jq ". + {name: \"${repo_name}\"}" - |
    jq '. + {private: true}' - |
    jq ". + {description: \"${description}\"}" - |
    jq --compact-output --sort-keys '.' -)"

  log_info "Creating gogs repository..."
  curl \
    --data "${create_data}" \
    --fail \
    --header "${content_type_app_json}" \
    --show-error \
    --silent \
    --user "${username}:${password}" \
    "${v1_api}/admin/users/${username}/repos" >/dev/null

  local webhook_config
  webhook_config="$(echo '{}' |
    jq ". + {url: \"https://${WEBHOOK_SINK_SERVICE_a8800f5b}\"}" - |
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

  log_info "Adding webhook..."
  curl \
    --data "${webhook_data}" \
    --fail \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "POST" \
    --show-error \
    --silent \
    "${v1_api}/repos/${username}/${repo_name}/hooks" >/dev/null

  log_info "Fetching..."
  git fetch \
    --all \
    --force \
    --recurse-submodules \
    --tags >/dev/null 2>&1

  log_info "Pushing branches..."
  git push \
    --all \
    --repo "${remote_name}" \
    --set-upstream >/dev/null 2>&1
  popd >/dev/null

  log_info "Success: $(basename "$0")"
}

main "$1"
