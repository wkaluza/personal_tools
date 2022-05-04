set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

SHELL_PREAMBLE="set -euo pipefail ; shopt -s inherit_errexit"

function format_single_shell_script
{
  local f="$1"

  shfmt -i 2 -fn -w "${f}" >/dev/null
}

function find_and_format_shell_scripts
{
  local project_root_dir="$1"

  local fn_name="format_single_shell_script"

  find "${project_root_dir}" \
    -type f \
    -and \( \
    -name '*.bash' -or \
    -name '*.sh' \) \
    -and -not \( \
    -path "${project_root_dir}/*___*/*" -or \
    -path "${project_root_dir}/.git/*" -or \
    -path "${project_root_dir}/.idea/*" \) \
    -exec bash -c "${SHELL_PREAMBLE} ; ${fn_name} \"\$1\"" -- {} \;
}

function analyse_single_shell_script
{
  local f="$1"

  local severity="style"
  # local severity="info"
  # local severity="warning"
  # local severity="error"

  shellcheck \
    --enable=all \
    --exclude="SC1090,SC1091,SC2002,SC2154,SC2310,SC2312" \
    --severity "${severity}" \
    --shell=bash \
    "${f}"
}

function find_and_analyse_shell_scripts
{
  local project_root_dir="$1"

  local fn_name="analyse_single_shell_script"

  find "${project_root_dir}" \
    -type f \
    -and \( \
    -name '*.bash' -or \
    -name '*.sh' \) \
    -and -not \( \
    -path "${project_root_dir}/*___*/*" -or \
    -path "${project_root_dir}/.git/*" -or \
    -path "${project_root_dir}/.idea/*" \) \
    -exec bash -c "${SHELL_PREAMBLE} ; ${fn_name} \"\$1\"" -- {} \;
}

function format_single_json_file
{
  local f="$1"

  local json_text
  json_text="$(cat "${f}")"
  echo "${json_text}" |
    jq --sort-keys '.' - >"${f}"
}

function find_and_format_json_files
{
  local project_root_dir="$1"

  local fn_name="format_single_json_file"

  find "${project_root_dir}" \
    -type f \
    -name '*.json' \
    -and -not \( \
    -path "${project_root_dir}/*___*/*" -or \
    -path "${project_root_dir}/.git/*" -or \
    -path "${project_root_dir}/.idea/*" \) \
    -exec bash -c "${SHELL_PREAMBLE} ; ${fn_name} \"\$1\"" -- {} \;
}

function sort_yaml
{
  local f="$1"

  cat <<EOF | python3 - >/dev/null
import yaml

def read_data(path):
    with open(path, 'r') as f:
        return yaml.safe_load(f)

def main(path):
    data = read_data(path)
    with open(path, 'w') as f:
        text = yaml.safe_dump(data, sort_keys=True)
        f.write(text)

if __name__ == '__main__':
    main('${f}')
EOF
}

function format_single_yaml_file
{
  local f="$1"

  # Destructive to YAML comments, use discretion
  # sort_yaml "${f}"

  prettier \
    --write "${f}" >/dev/null
}

function find_and_format_yaml_files
{
  local project_root_dir="$1"

  local fn_name="format_single_yaml_file"

  find "${project_root_dir}" \
    -type f \
    -and \( \
    -name '*.yaml' -or \
    -name '*.yml' \) \
    -and -not \( \
    -path "${project_root_dir}/*___*/*" -or \
    -path "${project_root_dir}/.git/*" -or \
    -path "${project_root_dir}/.idea/*" \) \
    -exec bash -c "${SHELL_PREAMBLE} ; ${fn_name} \"\$1\"" -- {} \;
}

function main
{
  local project_root_dir
  project_root_dir="$(realpath "${THIS_SCRIPT_DIR}/..")"

  export -f analyse_single_shell_script
  export -f format_single_json_file
  export -f format_single_shell_script
  export -f format_single_yaml_file
  export -f sort_yaml

  echo "Formatting..."

  find_and_format_json_files \
    "${project_root_dir}"

  find_and_format_shell_scripts \
    "${project_root_dir}"

  find_and_format_yaml_files \
    "${project_root_dir}"

  wait
  echo "Formatting done"

  echo "Performing static analysis..."

  find_and_analyse_shell_scripts \
    "${project_root_dir}"

  wait
  echo "Static analysis done"

  echo "Success: $(basename "$0")"
}

# Entry point
main
