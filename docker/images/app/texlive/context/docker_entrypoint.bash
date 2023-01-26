set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function main
{
  bash "${HOME}/run_texlive_zqn5plgk.bash" "$@"
}

main "$@"
