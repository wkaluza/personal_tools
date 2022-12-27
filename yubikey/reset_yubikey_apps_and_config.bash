set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function reset_yubikey_apps
{
  print_trace

  # log_info "Reset FIDO"
  # ykman fido reset
  # sleep 2

  log_info "Reset OATH"
  ykman oath reset --force
  sleep 2

  log_info "Reset OpenPGP"
  ykman openpgp reset --force
  sleep 2

  log_info "Reset PIV"
  ykman piv reset --force
  sleep 2

  log_info "Reset OTP slot 1"
  ykman otp static --generate --force 1
  sleep 2
  ykman otp delete --force 1
  sleep 2

  log_info "Reset OTP slot 2"
  ykman otp static --generate --force 2
  sleep 2
  ykman otp delete --force 2
  sleep 2
}

function adjust_config
{
  print_trace

  log_info "Enable NFC for all apps"
  ykman config nfc --force --enable-all
  sleep 2

  log_info "Enable USB for all apps"
  ykman config usb --force --enable-all
  sleep 2

  log_info "Enable USB touch-to-eject"
  ykman config usb --force --touch-eject
  sleep 2

  log_info "Set USB auto-eject timeout"
  ykman config usb --force --autoeject-timeout 14400
  sleep 2

  log_info "Set USB challenge-response timeout"
  ykman config usb --force --chalresp-timeout 30
  sleep 2
}

function ensure_unlocked_config
{
  print_trace

  local config_lock_code="$1"

  if ! quiet ykman config set-lock-code \
    --clear \
    --lock-code "${config_lock_code}"; then
    sleep 2
    quiet ykman config set-lock-code --clear
  fi
  sleep 2
}

function lock_config
{
  print_trace

  local config_lock_code="$1"

  ykman config set-lock-code --new-lock-code "${config_lock_code}"
  sleep 2
}

function main
{
  local config_lock_code="$1"

  reset_yubikey_apps
  ensure_unlocked_config "${config_lock_code}"
  adjust_config
  lock_config "${config_lock_code}"
}

# Entry point
main "$1"
