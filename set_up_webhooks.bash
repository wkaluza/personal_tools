set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function repo_exists
{
  local auth_header="$1"
  local username="$2"
  local receiver_json="$3"

  local repo_name
  repo_name="$(echo "${receiver_json}" |
    jq --raw-output '.repo.name' -)"

  if ! gogs_check_repo_exists \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${auth_header}" &>/dev/null; then
    return 1
  fi

  echo "${receiver_json}" |
    jq --sort-keys --compact-output '.' -
}

function augment_with_repo
{
  local receiver_json="$1"

  local source_name
  source_name="$(echo "${receiver_json}" |
    jq --raw-output '.source.name' -)"
  local source_namespace
  source_namespace="$(echo "${receiver_json}" |
    jq --raw-output '.source.namespace' -)"

  local source_url
  source_url="$(kubectl get gitrepository \
    --namespace "${source_namespace}" \
    --output json \
    "${source_name}" |
    jq --raw-output '.spec.url' -)"

  local escaped_git_host
  escaped_git_host="$(escape_dots "${DOMAIN_GIT_FRONTEND_df29c969}")"

  if ! echo "${source_url}" | grep -E "^ssh://git@${escaped_git_host}/.+/.+\.git$" &>/dev/null; then
    return 1
  fi

  local repo_json
  repo_json="$(echo "${source_url}" |
    sed -E "s|^ssh://git@${escaped_git_host}/(.+)/(.+)\.git$|{\"repo\": {\"name\":\"\2\",\"user\":\"\1\"}}|")"

  echo "${receiver_json}" |
    jq \
      --compact-output \
      --sort-keys \
      ". + ${repo_json}" -
}

function get_receivers
{
  kubectl get \
    --all-namespaces \
    --output json \
    receiver |
    jq \
      --sort-keys \
      '.items[]' - |
    jq \
      'if .spec.resources | length == 1 then . else error("Unexpected resource count") end' - |
    jq \
      'if .spec.resources[0].kind == "GitRepository" then . else error("Unexpected resource kind") end' - |
    jq \
      --compact-output \
      --sort-keys \
      '{ name: .metadata.name , namespace: .metadata.namespace , path: .status.url , source: { name: .spec.resources[0].name , namespace: .spec.resources[0].namespace } }' - |
    sort |
    uniq |
    for_each augment_with_repo
}

function webhook_service_url
{
  local protocol="https"

  echo "${protocol}://${DOMAIN_WEBHOOK_SINK_a8800f5b}"
}

function webhook_exists
{
  local username="$1"
  local auth_header="$2"
  local repo_name="$3"
  local webhook_url="$4"

  gogs_list_webhooks \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${auth_header}" \
    "${repo_name}" |
    jq ". | map( select( .config.url == \"${webhook_url}\" ) )" - |
    quiet jq "if . | length == 0 then error(\"Webhook not found: ${webhook_url}\") else . end" -
}

function escape_dots
{
  local input="$1"

  echo "${input}" | sed -E 's|\.|\\.|g'
}

function create_webhook_for_receiver
{
  local auth_header="$1"
  local username="$2"
  local receiver_json="$3"

  local source_name
  source_name="$(echo "${receiver_json}" |
    jq --raw-output '.source.name' -)"
  local source_namespace
  source_namespace="$(echo "${receiver_json}" |
    jq --raw-output '.source.namespace' -)"
  local webhook_path
  webhook_path="$(echo "${receiver_json}" |
    jq --raw-output '.path' -)"
  local repo_name
  repo_name="$(echo "${receiver_json}" |
    jq --raw-output '.repo.name' -)"

  local webhook_url
  webhook_url="$(webhook_service_url)${webhook_path}"

  if ! webhook_exists \
    "${username}" \
    "${auth_header}" \
    "${repo_name}" \
    "${webhook_url}"; then
    log_info "Creating webhook for ${username}/${repo_name} aimed at ${webhook_url}"

    quiet gogs_create_webhook \
      "${DOMAIN_GIT_FRONTEND_df29c969}" \
      "${webhook_url}" \
      "${username}" \
      "$(pass_show_or_generate "local_gogs_webhook_secret")" \
      "${auth_header}" \
      "${repo_name}"
  fi
}

function create_webhooks_for_all_receivers
{
  local auth_header="$1"
  local username="$2"

  get_receivers |
    for_each filter repo_exists \
      "${auth_header}" \
      "${username}" |
    for_each create_webhook_for_receiver \
      "${auth_header}" \
      "${username}"
}

function wait_for_receivers_ready
{
  quiet kubectl wait \
    --all-namespaces \
    receiver \
    --all \
    --for="condition=Ready" \
    --timeout="60s"
}

function delete_webhook
{
  local username="$1"
  local auth_header="$2"
  local repo_name="$3"
  local hook_id="$4"

  log_info "Deleting webhook ${hook_id} from ${username}/${repo_name}"

  gogs_delete_webhook \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${auth_header}" \
    "${repo_name}" \
    "${hook_id}"
}

function delete_webhooks_for_repo
{
  local username="$1"
  local auth_header="$2"
  local repo_name="$3"

  gogs_list_webhooks \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${auth_header}" \
    "${repo_name}" |
    jq --raw-output '.[] | .id' - |
    for_each delete_webhook \
      "${username}" \
      "${auth_header}" \
      "${repo_name}"
}

function delete_webhooks_for_all_repos
{
  local auth_header="$1"
  local username="$2"

  gogs_list_own_repos \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${auth_header}" \
    "${username}" |
    for_each delete_webhooks_for_repo \
      "${username}" \
      "${auth_header}"
}

function main
{
  local username="wkaluza"
  local token
  token="$(pass show "local_gogs_token_${username}")"
  local auth_header="Authorization: token ${token}"

  wait_for_receivers_ready
  delete_webhooks_for_all_repos \
    "${auth_header}" \
    "${username}"
  create_webhooks_for_all_receivers \
    "${auth_header}" \
    "${username}"

  log_info "Success $(basename "$0")"
}

# Entry point
main
