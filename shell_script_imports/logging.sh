#!/usr/bin/env bash

set -euo pipefail

function log_info() {
  local message="$1"

  echo "INFO: $message"
}

function log_warning() {
  local message="$1"

  echo "WARNING: $message"
}

function log_error() {
  local message="$1"

  echo "ERROR: $message"
}
