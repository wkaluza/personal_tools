set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local repo_name="$1"
  local repo_description="$2"

  local repo_url="git@github.com:wkaluza/${repo_name}"

  gh api user/repos \
    --method POST \
    --header "Accept: application/vnd.github.v3+json" \
    --field private=true \
    --field has_issues=false \
    --field has_projects=false \
    --field has_wiki=false \
    --field allow_squash_merge=true \
    --field allow_merge_commit=false \
    --field allow_rebase_merge=false \
    --field delete_branch_on_merge=true \
    --field name="${repo_name}" \
    --field description="${repo_description}"

  git init "${repo_name}"
  cd "${repo_name}"
  git remote add origin "${repo_url}"
  git fetch --all --recurse-submodules --tags

  git commit --allow-empty --message "Repository root"

  local gitignore_name=".gitignore"

  echo "*___*" >"${gitignore_name}"
  git add "${gitignore_name}"
  git commit --message "Add Git ignore file"

  git push --set-upstream origin main
}

# Entry point
main "$1" "$2"
