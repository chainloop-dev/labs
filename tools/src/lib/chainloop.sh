## Usage:
## Use any of the functions below to color or format a portion of a string.
##
##   echo "before $(red this is red) after"
##   echo "before $(green_bold this is green_bold) after"
##
## Color output will be disabled if `NO_COLOR` environment variable is set
## in compliance with https://no-color.org/
##
print_in_color() {
  local color="$1"
  shift
  if [[ -z ${NO_COLOR+x} ]]; then
    printf "$color%b\e[0m\n" "$*"
  else
    printf "%b\n" "$*"
  fi
}

red() { print_in_color "\e[31m" "$*"; }
green() { print_in_color "\e[32m" "$*"; }
yellow() { print_in_color "\e[33m" "$*"; }
blue() { print_in_color "\e[34m" "$*"; }
magenta() { print_in_color "\e[35m" "$*"; }
cyan() { print_in_color "\e[36m" "$*"; }
bold() { print_in_color "\e[1m" "$*"; }
underlined() { print_in_color "\e[4m" "$*"; }
red_bold() { print_in_color "\e[1;31m" "$*"; }
green_bold() { print_in_color "\e[1;32m" "$*"; }
yellow_bold() { print_in_color "\e[1;33m" "$*"; }
blue_bold() { print_in_color "\e[1;34m" "$*"; }
magenta_bold() { print_in_color "\e[1;35m" "$*"; }
cyan_bold() { print_in_color "\e[1;36m" "$*"; }
red_underlined() { print_in_color "\e[4;31m" "$*"; }
green_underlined() { print_in_color "\e[4;32m" "$*"; }
yellow_underlined() { print_in_color "\e[4;33m" "$*"; }
blue_underlined() { print_in_color "\e[4;34m" "$*"; }
magenta_underlined() { print_in_color "\e[4;35m" "$*"; }
cyan_underlined() { print_in_color "\e[4;36m" "$*"; }

###

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
  if [ ! is_chainloop_in_path ]; then
    exit 1
  fi
}

l() {
  yellow "$*"
}

###
# helpers
t=$(date "+%Y%m%d%H%M%S")
script_dir="$(cd "$(dirname "$0")" && pwd)"
CHAINLOOP_TMP_DIR="${CHAINLOOP_TMP_DIR:-${script_dir}/tmp/chainloop}"

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

validate_chainloop_required_env_vars() {
  if [ -z "${CHAINLOOP_ROBOT_ACCOUNT}" ]; then
    log_error "CHAINLOOP_ROBOT_ACCOUNT is not set"
    return 1
  fi
  if [ -z "${CHAINLOOP_VERSION+x}" ]; then
    CHAINLOOP_VERSION=""
  fi
  if [ -z "${CHAINLOOP_SIGNING_KEY}" ]; then
    log_error "CHAINLOOP_SIGNING_KEY is not set"
    return 1
  fi
  if [[ -z "${CHAINLOOP_SIGNING_PASSWORD+x}" ]]; then
    log_error "CHAINLOOP_SIGNING_PASSWORD is not set"
    return 1
  fi
}

export CHAINLOOP_BIN_PATH="${CHAINLOOP_BIN_PATH:-/usr/local/bin/chainloop}"

chainloop_bin_install() {
  # it takes the list of paths and installs them in the CHAINLOOP_BIN_PATH
  # it creates the directory if it does not exist
  # it makes the files executable
  # make sure to detect the basename of the path and properly make the target file executable
  mkdir -p $CHAINLOOP_BIN_PATH
  for path in $@; do
    if [ -f $path ]; then
      log "Installing $path"
      cp $path $CHAINLOOP_BIN_PATH
      chmod +x $CHAINLOOP_BIN_PATH/$(basename $path)
    else
      log_error "chainloop_bin_install: path $path does not exist"
      return 1
    fi
  done
}

# chainloop_bin_cache_in_dir - it takes a path and copy there the CHAINLOOP_BIN_PATH
chainloop_bin_cache_in_dir() {
  mkdir -p $1
  cp -r $CHAINLOOP_BIN_PATH/* $1
}

# chainloop_recreate_env_from_cache - it takes the path to the file in the format .env_NAME and export env variable NAME=`what is in the file`
# for instance .c8l_cache/.env_chainloop_attestation_id end exports variable CHAINLOOP_ATTESTATION_ID with the value from the file
# or .c8l_cache/.env_chainloop_signing_key_path end exports variable CHAINLOOP_SIGNING_KEY_PATH with the value from the file
# it validates the file exists and is not empty and the file name is in the format .env_NAME
chainloop_recreate_env_from_file() {
  path=$1
  # if the path is empty or does not exist, return
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    log_error "chainloop_recreate_env_from_file: path $path does not exist"
    return 1
  fi
  file=$(basename $path)
  if [[ $file =~ ^\.env_.*$ ]]; then
    export $(echo $file | sed 's/\.env_//')=$(cat $path)
  else
    log_error "File $file is not in the format .env_NAME"
    return 1
  fi
}

# chainloop_save_env_to_file - it takes the name of the env variable and saves it to the file in the format .env_NAME
chainloop_save_env_to_file() {
  name=$1
  dir=$2
  if [ -z "${name}" ]; then
    log_error "Name is not set"
    return 1
  fi
  # if $dir is empty or directory #$dir does not exist, return
  if [ -z "${dir}" ] || [ ! -d "${dir}" ]; then
    log_error "Directory $dir does not exist"
    return 1
  fi
  if [ -z "${!name}" ]; then
    log_error "Variable $name is not set"
    return 1
  fi
  echo "${!name}" >$dir/.env_${name}
}

# chainloop_save_env_to_cache - it takes the cache directory which is the first parameter and then the list of env variables which are saved to the cache
# it validates directory exists and is a directory
chainloop_save_env_to_cache() {
  cache_dir=$1
  if [ -z "${cache_dir}" ] || [ ! -d "${cache_dir}" ]; then
    log_error "Cache directory $cache_dir does not exist"
    return 1
  fi
  for name in "${@:2}"; do
    chainloop_save_env_to_file $name $cache_dir
  done
}

# chainloop_restore_env_all_from_cache - it finds all the .env_NAME files in the directory specified as first argument and exports the env variables
# it validates if the directory exists and is a directory
chainloop_restore_env_all_from_cache() {
  cache_dir=$1
  if [ -z "${cache_dir}" ] || [ ! -d "${cache_dir}" ]; then
    log_error "Cache directory $cache_dir does not exist"
    return 1
  fi
  for file in $cache_dir/.env_*; do
    chainloop_recreate_env_from_file $file
  done
}

# chainloop_restore_all_from_cache - it restores the env variables and the tools from the cache
# it takes the cache directory as the first parameter and validates if it exists and is a directory
chainloop_restore_all_from_cache() {
  cache_dir=$1
  if [ -z "${cache_dir}" ] || [ ! -d "${cache_dir}" ]; then
    log_error "Cache directory $cache_dir does not exist"
    return 1
  fi
  chainloop_restore_env_all_from_cache $cache_dir
  chainloop_bin_install $cache_dir/*
}

###

# chainloop_install takes the list of tools and installs them with functions below install_${name}
chainloop_install() {
  for tool in $@; do
    install_${tool}
  done
}

generic_install() {
  file=$1
  url=$2
  file_path=$CHAINLOOP_BIN_PATH/$file

  mkdir -p $CHAINLOOP_BIN_PATH
  log "Installing $file"
  curl -sfL $url -o $file_path
  if [ $? -ne 0 ]; then
    log_error "$file installation failed"
    return 1
  fi
  chmod +x $file_path
}
###

install_chainloop_cli() {
  mkdir -p ${CHAINLOOP_TMP_DIR} $CHAINLOOP_BIN_PATH
  log "Installing Chainloop CLI"
  if [ -n "${CHAINLOOP_VERSION}" ]; then
    curl -sfL https://docs.chainloop.dev/install.sh | bash -s -- --version v${CHAINLOOP_VERSION} --path $CHAINLOOP_BIN_PATH
  else
    curl -sfL https://docs.chainloop.dev/install.sh | bash -s -- --path $CHAINLOOP_BIN_PATH
  fi
  if [ $? -ne 0 ]; then
    log_error "Chainloop installation failed"
    return 1
  fi
}

install_cosign() {
  generic_install cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
}

install_chainloop_cli_and_cosign() {
  install_cosign
  install_chainloop_cli
}

install_syft() {
  log "Installing Syft"
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b $CHAINLOOP_BIN_PATH
  if [ $? -ne 0 ]; then
    log_error "Syft installation failed"
    return 1
  fi
}

install_semgrep() {
  log "Installing Semgrep"
  python3 -m pip install semgrep -q >$CHAINLOOP_TMP_DIR/install_semgrep.log
  if [ $? -ne 0 ]; then
    log_error "Semgrep installation failed"
    return 1
  fi
}

install_conftest() {
  LATEST_VERSION=$(wget -O - "https://api.github.com/repos/open-policy-agent/conftest/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 2-)
  wget -q "https://github.com/open-policy-agent/conftest/releases/download/v${LATEST_VERSION}/conftest_${LATEST_VERSION}_Linux_x86_64.tar.gz" >$CHAINLOOP_TMP_DIR/install_wget.log
  tar xzf conftest_${LATEST_VERSION}_Linux_x86_64.tar.gz
  $SUDO_CMD mv conftest $CHAINLOOP_BIN_PATH
}

install_oras() {
  log "Installing Oras"
  VERSION="1.0.0"
  curl -sLO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
  mkdir -p oras-install/
  tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
  $SUDO_CMD mv oras-install/oras $CHAINLOOP_BIN_PATH
  rm -rf oras_${VERSION}_*.tar.gz oras-install/
  oras version
  if [ $? -ne 0 ]; then
    log_error "Oras installation failed"
    return 1
  fi
}

install_jq() {
  log "Installing jq"
  $SUDO_CMD apt-get install jq -y >$CHAINLOOP_TMP_DIR/install_jq.log
  if [ $? -ne 0 ]; then
    log_error "jq installation failed"
    return 1
  fi
}

install_ruby_restclient() {
  log "Installing Ruby rest-client"
  $SUDO_CMD gem install rest-client >$CHAINLOOP_TMP_DIR/install_ruby_restclient.log
  if [ $? -ne 0 ]; then
    log_error "rest-client installation failed"
    return 1
  fi
}

install_yq() {
  generic_install yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
}

install_parlay() {
  log "Installing Parlay"
  wget -q https://github.com/snyk/parlay/releases/latest/download/parlay_Linux_x86_64.tar.gz >$CHAINLOOP_TMP_DIR/install_parlay.log
  tar -xvf parlay_Linux_x86_64.tar.gz
  $SUDO_CMD mv parlay $CHAINLOOP_BIN_PATH
  rm parlay_Linux_x86_64.tar.gz
}

spdx2cyclonedx() {
  spdx_file=$1
  cyclonedx_file=$2
  syft convert "${spdx_file}" -o cyclonedx-json="${cyclonedx_file}"
  if [ $? -ne 0 ]; then
    log_error "SPDX to CycloneDX conversion failed"
    return 1
  fi
}

install_chainloop_tools() {
  log_header "Installing Chainloop Tools"
  export PATH=$CHAINLOOP_BIN_PATH:$PATH

  if [ -f $CHAINLOOP_BIN_PATH/chainloop ]; then
    log "Skipping... Chainloop Tools already installed"
    return 0
  fi

  install_chainloop_cli_and_cosign
  install_syft
  install_semgrep
  install_oras
  install_jq
  install_yq
  install_parlay
}

###

chainloop_attestation_add_from_yaml() {
  export ATTESTATION_NAME=$1
  if [ -z "${ATTESTATION_NAME}" ]; then
    export ATTESTATION_NAME="attestation"
  fi
  log "Adding Metadata files based on .chainloop.yml"
  script=$(cat .chainloop.yml | yq eval '.[strenv(ATTESTATION_NAME)][] | "chainloop attestation add --name "  + .name + " --value " + .path + " --remote-state --attestation-id ${CHAINLOOP_ATTESTATION_ID} 2>&1; "')
  log $script
  eval $script
}

chainloop_attestation_init() {
  log "Initializing Chainloop Attestation"
  CR_VALUE=""
  if [ -n "${CHAINLOOP_CONTRACT_REVISION}" ]; then
    CR_VALUE="--contract-revision ${CHAINLOOP_CONTRACT_REVISION}"
  fi
  r=$(chainloop attestation init -f --remote-state --output json $CR_VALUE)
  if [ $? -ne 0 ]; then
    log_error "Chainloop initialization failed: $r"
    return 1
  fi
  export CHAINLOOP_ATTESTATION_ID=$(echo $r | grep attestationID | awk -F\" '{print $4}')
  log "Attestation ID: $CHAINLOOP_ATTESTATION_ID"
}

chainloop_attestation_status() {
  log "Checking Attestation Status"
  if chainloop attestation status --full --remote-state --attestation-id "${CHAINLOOP_ATTESTATION_ID}" &>c8-status.txt; then
    log "Attestation Status Process Completed Successfully"
    cat c8-status.txt
  else
    exit_code=$?
    log_error "Attestation Status Process Failed"
    cat c8-status.txt
    return $exit_code
  fi
}

chainloop_attestation_push() {
  log "Pushing Attestation"
  if [ -n "${CHAINLOOP_USE_INSECURE_KEY}" ]; then
    log "# USING INSECURE KEY BECAUSE CHAINLOOP_USE_INSECURE_KEY is set"
    CHAINLOOP_SIGNING_KEY_PATH="cosign.key"
    export CHAINLOOP_SIGNING_PASSWORD=""
    export COSIGN_PASSWORD="$CHAINLOOP_SIGNING_PASSWORD"
    cosign generate-key-pair
  fi
  if [ -z "${CHAINLOOP_SIGNING_KEY_PATH+x}" ]; then
    log "  with CHAINLOOP_SIGNING_KEY"
    tmp_key="${CHAINLOOP_TMP_DIR}/key"
    mkdir -p "${CHAINLOOP_TMP_DIR}"
    echo "${CHAINLOOP_SIGNING_KEY}" >$tmp_key
  else
    log "  with CHAINLOOP_SIGNING_KEY_PATH"
    tmp_key="${CHAINLOOP_SIGNING_KEY_PATH}"
  fi
  # chainloop attestation push --key env://CHAINLOOP_SIGNING_KEY
  if chainloop attestation push --key $tmp_key --remote-state --attestation-id "${CHAINLOOP_ATTESTATION_ID}" &>c8-push.txt; then
    log "Attestation Process Completed Successfully"
    cat c8-push.txt
    rm $tmp_key
  else
    exit_code=$?
    log_error "Attestation Process Failed"
    cat c8-push.txt
    rm $tmp_key
    return $exit_code
  fi
}

prepare_tmp_file() {
  tmp_dir="${CHAINLOOP_TMP_DIR}"
  file_name=$1
  mkdir -p "${tmp_dir}"
  t="${tmp_dir}/${file_name}"
  if [ -f $t ]; then
    echo "Temporary file file $t already exists"
    return 1
  fi
  echo $t
}

chainloop_summary() {
  tmpfile=$(prepare_tmp_file report.txt)
  if [ $? -ne 0 ]; then
    log $tmpfile
    return 1
  fi
  echo -e "## Great job!\n\nYou are making SecOps and Compliance teams really happy. Keep up the good work!\n" >>$tmpfile

  digest=""
  if [ -f c8-push.txt ]; then
    digest=$(cat c8-push.txt | grep " Digest: " | awk -F\  '{print $3}')
    echo "**[Chainloop Trust Report]( https://app.chainloop.dev/attestation/${digest} )**" >>$tmpfile
    echo "\`\`\`" >>$tmpfile
    cat c8-status.txt >>$tmpfile
    echo "\`\`\`" >>$tmpfile
  fi
  cat $tmpfile
  rm $tmpfile
}

chainloop_generate_github_summary() {
  log "Generating GitHub Summary"
  chainloop_summary >>$GITHUB_STEP_SUMMARY
}

chainloop_summary_on_failure() {
  tmpfile=$(prepare_tmp_file report_on_failure.txt)
  echo -e "## Chainloop Attestation Failed\nWe were unable to complete the Chainloop attestation process due to unmet SecOps and Compliance requirements:" >>$tmpfile
  if [ -f c8-push.txt ]; then
    echo -e "\n> [!WARNING]" >>$tmpfile
    cat c8-push.txt | sed -r "s/[[:cntrl:]]\[[0-9]{1,3}m//g" | sed 's/^/> /' >>$tmpfile
    echo -e "\n" >>$tmpfile
  fi
  if [ -f c8-status.txt ]; then
    echo "\`\`\`" >>$tmpfile
    cat c8-status.txt | sed -r "s/[[:cntrl:]]\[[0-9]{1,3}m//g" >>$tmpfile
    echo "\`\`\`" >>$tmpfile
  fi
  cat $tmpfile
  rm $tmpfile
}

chainloop_generate_github_summary_on_failure() {
  log "Generating GitHub Summary on Failure"
  chainloop_summary_on_failure >>$GITHUB_STEP_SUMMARY
}

chainloop_collect_logs_for_github_jobs() {
  log "Collecting logs for GitHub Jobs"
  # GH_TOKEN or GITHUB_TOKEN is required for this to work
  # https://docs.github.com/en/rest/actions/workflow-jobs?apiVersion=2022-11-28#download-job-logs-for-a-workflow-run
  mkdir -p metadata/gh_logs
  gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs >metadata/gh_logs/jobs.json
  for j in $(cat metadata/gh_logs/jobs.json | jq '.jobs[].id'); do
    gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/${GITHUB_REPOSITORY}/actions/jobs/${j}/logs >metadata/gh_logs/${j}.log
  done
}

install_chainloop_labs() {
  mkdir -p ${CHAINLOOP_TMP_DIR}
  branch=${1:-main}
  generic_install c8l https://raw.githubusercontent.com/chainloop-dev/labs/${branch}/tools/c8l
}

# how to use it:
#   source <(c8l source)
source_chainloop_labs() {
  script_path=$(readlink -f "$0")
  echo "export PATH=\"/usr/local/bin:$CHAINLOOP_BIN_PATH:$PATH\""
  cat $script_path | sed '$d' | sed '$d'
}
