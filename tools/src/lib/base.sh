export CHAINLOOP_BIN_PATH="${CHAINLOOP_BIN_PATH:-/usr/local/bin/chainloop_bin}"

is_chainloop_in_path() {
  if command -v chainloop &>/dev/null; then
    # we are good
    return 0
  else
    log "chainloop is not in PATH, install it."
    return 1
  fi
}

validate_env() {
  is_chainloop_in_path
  if [ ! $? ]; then
    exit 1
  fi
}

t=$(date "+%Y%m%d%H%M%S")
script_dir="$(cd "$(dirname "$0")" && pwd)"
CHAINLOOP_TMP_DIR="${CHAINLOOP_TMP_DIR:-${script_dir}/tmp/chainloop}"

l() {
  yellow "$*"
}

log() {
  # echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
  yellow "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

log_error() {
  red_bold "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

log_header() {
  blue_bold "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

prepare_tmp_file() {
  tmp_dir="${CHAINLOOP_TMP_DIR}"
  file_name=$1
  mkdir -p "${tmp_dir}"
  t="${tmp_dir}/${file_name}"
  if [ -f "$t" ]; then
    echo "Temporary file file $t already exists"
    return 1
  fi
  echo "$t"
}