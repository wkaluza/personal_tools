set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function gogs_list_webhooks
{
  local gogs_host="$1"
  local username="$2"
  local auth_header="$3"
  local repo_name="$4"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  curl \
    --fail \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "GET" \
    --show-error \
    --silent \
    "${v1_api}/repos/${username}/${repo_name}/hooks"
}

function gogs_create_webhook
{
  local gogs_host="$1"
  local webhook_url="$2"
  local username="$3"
  local gogs_webhook_secret="$4"
  local auth_header="$5"
  local repo_name="$6"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  local webhook_config
  webhook_config="$(echo '{}' |
    jq ". + {url: \"${webhook_url}\"}" - |
    jq ". + {content_type: \"json\"}" - |
    jq ". + {secret: \"${gogs_webhook_secret}\"}" - |
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
    --header "${content_type_app_json}" \
    --request "POST" \
    --show-error \
    --silent \
    "${v1_api}/repos/${username}/${repo_name}/hooks"
}

function gogs_delete_webhook
{
  local gogs_host="$1"
  local username="$2"
  local auth_header="$3"
  local repo_name="$4"
  local hook_id="$5"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  curl \
    --fail \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "DELETE" \
    --show-error \
    --silent \
    "${v1_api}/repos/${username}/${repo_name}/hooks/${hook_id}"
}

function gogs_check_repo_exists
{
  local gogs_host="$1"
  local username="$2"
  local repo_name="$3"
  local auth_header="$4"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  quiet curl \
    --fail \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --show-error \
    --silent \
    "${v1_api}/repos/${username}/${repo_name}"
}

function gogs_list_own_repos
{
  local gogs_host="$1"
  local auth_header="$2"
  local username="$3"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  curl \
    --fail \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --show-error \
    --silent \
    "${v1_api}/user/repos" 2>&1 |
    jq ".[] | select( .owner.username == \"${username}\" )" - |
    jq --raw-output '.full_name' - |
    sed -E "s|^.+/(.+)$|\1|"
}

function gogs_delete_repo
{
  local gogs_host="$1"
  local username="$2"
  local repo_name="$3"
  local auth_header="$4"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  curl \
    --fail \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "DELETE" \
    --show-error \
    --silent \
    "${v1_api}/repos/${username}/${repo_name}"
}

function gogs_create_repo
{
  local gogs_host="$1"
  local username="$2"
  local repo_name="$3"
  local description="$4"
  local auth_header="$5"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

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
    --header "${content_type_app_json}" \
    --show-error \
    --silent \
    "${v1_api}/admin/users/${username}/repos"
}

function gogs_list_token_names
{
  local gogs_host="$1"
  local username="$2"
  local password="$3"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  curl \
    --header "${content_type_app_json}" \
    --request "GET" \
    --silent \
    --user "${username}:${password}" \
    "${v1_api}/users/${username}/tokens" |
    jq --raw-output '.[].name' -
}

function gogs_generate_token
{
  local gogs_host="$1"
  local username="$2"
  local password="$3"
  local token_name="$4"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  curl \
    --data "{\"name\": \"${token_name}\"}" \
    --header "${content_type_app_json}" \
    --request "POST" \
    --silent \
    --user "${username}:${password}" \
    "${v1_api}/users/${username}/tokens" |
    jq --raw-output '.sha1' -
}

function gogs_get_single_user
{
  local gogs_host="$1"
  local username="$2"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  curl \
    --fail \
    --header "${content_type_app_json}" \
    --silent \
    "${v1_api}/users/${username}"
}

function gogs_docker_cli_create_admin_user
{
  local docker_stack_name="$1"
  local cli_path="$2"
  local email="$3"
  local username="$4"
  local password="$5"

  local gogs_service
  gogs_service="$(docker stack services \
    --format '{{ .Name }}' \
    "${docker_stack_name}" |
    grep "gogs" |
    head -n1)"

  local container
  container="$(docker service ps \
    --filter 'desired-state=running' \
    --format '{{ .Name }}.{{ .ID }}' \
    --no-trunc \
    "${gogs_service}" |
    head -n1)"

  docker exec \
    --user "git" \
    "${container}" \
    "${cli_path}" admin create-user \
    --admin \
    --email "${email}" \
    --name "${username}" \
    --password "${password}"
}

function gogs_ssh_key_exists
{
  local gogs_host="$1"
  local username="$2"
  local ssh_key_name="$3"
  local auth_header="$4"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  local output
  output="$(curl \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "GET" \
    --silent \
    "${v1_api}/user/keys" |
    jq ".[] | select(.title == \"${ssh_key_name}\")" -)"

  if ! echo "${output}" |
    jq --raw-output '.title' - |
    grep -E "^${ssh_key_name}$" &>/dev/null; then
    return 1
  fi

  echo "${output}" |
    jq --raw-output '.key' -
}

function gogs_create_ssh_key
{
  local gogs_host="$1"
  local ssh_key_name="$2"
  local ssh_public_key="$3"
  local auth_header="$4"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  local data
  data="$(echo '{}' |
    jq ". + {title: \"${ssh_key_name}\"}" - |
    jq ". + {key: \"${ssh_public_key}\"}" - |
    jq --compact-output --sort-keys '.' -)"

  quiet curl \
    --data "${data}" \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "POST" \
    --silent \
    "${v1_api}/user/keys"
}

function gogs_delete_ssh_key
{
  local gogs_host="$1"
  local ssh_key_name="$2"
  local auth_header="$3"

  local content_type_app_json="Content-Type: application/json"
  local v1_api="https://${gogs_host}/api/v1"

  local output
  output="$(curl \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "GET" \
    --silent \
    "${v1_api}/user/keys" |
    jq ".[] | select(.title == \"${ssh_key_name}\")" -)"

  echo "${output}" |
    jq --raw-output '.title' - |
    quiet grep -E "^${ssh_key_name}$"

  local id
  id="$(echo "${output}" | jq --raw-output '.id' -)"

  quiet curl \
    --header "${auth_header}" \
    --header "${content_type_app_json}" \
    --request "DELETE" \
    --silent \
    "${v1_api}/user/keys/${id}"
}
