set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

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

  log_info "Fetching..."
  git fetch \
    --all \
    --force \
    --recurse-submodules \
    --tags >/dev/null 2>&1

  for branch in $(git branch -l |
    sed -E 's/^[ *] (.+)$/\1/'); do
    log_info "Pushing local branch ${branch}..."
    git push \
      "${remote_name}" \
      --set-upstream "${branch}" >/dev/null 2>&1
  done

  popd >/dev/null

  log_info "Success: $(basename "$0")"
}

main "$1"
