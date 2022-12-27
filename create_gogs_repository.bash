set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  local repo_dir
  repo_dir="$(realpath "$1")"
  local repo_name="$2"
  local repo_description="$3"

  local username="wkaluza"
  local token
  token="$(pass show "local_gogs_token_${username}")"
  local auth_header="Authorization: token ${token}"

  local repo_url="git@${DOMAIN_GIT_FRONTEND_df29c969}:${username}/${repo_name}.git"

  quiet gogs_create_repo \
    "${DOMAIN_GIT_FRONTEND_df29c969}" \
    "${username}" \
    "${repo_name}" \
    "${repo_description}" \
    "${auth_header}"

  mkdir --parents "${repo_dir}"
  git clone "${repo_url}" "${repo_dir}"
  cd "${repo_dir}"

  git commit --allow-empty --message "Repository root"

  local gitignore_name=".gitignore"

  echo "*___*" >"${gitignore_name}"
  git add "${gitignore_name}"
  git commit --message "Add Git ignore file"

  git push

  echo "Success $(basename "$0")"
}

# Entry point
main "$1" "$2" "$3"
