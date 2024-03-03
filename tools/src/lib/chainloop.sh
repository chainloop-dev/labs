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

###

install_chainloop_cli() {
  mkdir -p ${CHAINLOOP_TMP_DIR}
  log "Installing Chainloop CLI"
  if [ -n "${CHAINLOOP_VERSION}" ]; then
    curl -sfL https://docs.chainloop.dev/install.sh | bash -s -- --version v${CHAINLOOP_VERSION}
  else
    curl -sfL https://docs.chainloop.dev/install.sh | bash -s
  fi
  if [ $? -ne 0 ]; then
    log_error "Chainloop installation failed"
    return 1
  fi
}

install_cosign() {
  log "Installing Cosign"
  curl -sfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
  if [ $? -ne 0 ]; then
    log_error "Cosign installation failed"
    return 1
  fi
  chmod +x /usr/local/bin/cosign
}

install_chainloop_cli_and_cosign() {
  install_cosign
  install_chainloop_cli
  mv /usr/local/bin/cosign /usr/local/bin/chainloop .
}

install_syft() {
  log "Installing Syft"
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
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
  $SUDO_CMD mv conftest /usr/local/bin
}

install_oras() {
  log "Installing Oras"
  VERSION="1.0.0"
  curl -sLO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
  mkdir -p oras-install/
  tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
  $SUDO_CMD mv oras-install/oras /usr/local/bin/
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
  log "Installing yq"
  $SUDO_CMD wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  if [ $? -ne 0 ]; then
    log_error "yq installation failed"
    return 1
  fi
  $SUDO_CMD chmod a+x /usr/local/bin/yq
}

install_parlay() {
  log "Installing Parlay"
  wget -q https://github.com/snyk/parlay/releases/latest/download/parlay_Linux_x86_64.tar.gz >$CHAINLOOP_TMP_DIR/install_parlay.log
  tar -xvf parlay_Linux_x86_64.tar.gz
  $SUDO_CMD mv parlay /usr/local/bin/
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
  export PATH=/usr/local/bin:$PATH

  if [ -f /usr/local/bin/chainloop ]; then
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
  log "Adding Metadata files based on .chainloop.yml to attestation"
  script=$(cat .chainloop.yml | yq eval '.attestation[] | "chainloop attestation add --name "  + .name + " --value " + .path + " --remote-state --attestation-id ${ATT_ID} 2>&1; "')
  eval $script
}

chainloop_attestation_init() {
  log "Initializing Chainloop Attestation"
  CR_VALUE=""
  if [ -n "${CHAINLOOP_CONTRACT_REVISION}" ]; then
    CR_VALUE="--contract-revision ${CHAINLOOP_CONTRACT_REVISION}"
  fi
  r=$(chainloop attestation init -f --remote-state --output json $CR_VALUE 2>&1)
  if [ $? -ne 0 ]; then
    log_error "Chainloop initialization failed: $r"
    exit 1
  fi
  export CHAINLOOP_ATTESTATION_ID=$(echo $r | grep attestationID | awk -F\" '{print $4}')
  log "Attestation ID: $CHAINLOOP_ATTESTATION_ID"
}

chainloop_attestation_status() {
  log "Checking Attestation Status"
  if chainloop attestation status --full --remote-state --attestation-id "${ATT_ID}" &>c8-status.txt; then
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
    CHAINLOOP_SIGNING_PASSWORD="insecure"
    echo $CHAINLOOP_SIGNING_KEY | cosign generate-key-pair
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
  if chainloop attestation push --key $tmp_key --remote-state --attestation-id "${ATT_ID}" &>c8-push.txt; then
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
    log_error "TMP file $tmp_file already exists"
    return 1
  fi
  echo $t
}

chainloop_summary() {
  tmpfile=$(prepare_tmp_file report.txt)
  digest=$(cat c8-push.txt | grep " Digest: " | awk -F\  '{print $3}')
  echo -e "## Great job!\n\nYou are making SecOps and Compliance teams really happy. Keep up the good work!\n" >>$tmpfile
  echo "**[Chainloop Trust Report]( https://app.chainloop.dev/attestation/${digest} )**" >>$tmpfile
  echo "\`\`\`" >>$tmpfile
  cat c8-status.txt >>$tmpfile
  echo "\`\`\`" >>$tmpfile
  cat $tmpfile
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

install_chainloop_labs_cli() {
  log "Installing Chainloop Labs CLI"
  mkdir -p metadata
  branch=${1:-main}
  $SUDO_CMD curl -sfL https://raw.githubusercontent.com/chainloop-dev/labs/${branch}/tools/c8l -o /usr/local/bin/c8l
  if [ $? -ne 0 ]; then
    log_error "Failed to install labs CLI"
    return 1
  fi
  $SUDO_CMD chmod +x /usr/local/bin/c8l
}

install_chainloop_labs() {
  log "Installing Chainloop Labs"
  branch=${1:-main}

  mkdir -p ${CHAINLOOP_TMP_DIR}

  install_chainloop_labs_cli ${branch}
}

# how to use it:
#   source <(c8l source)
source_chainloop_labs() {
  script_path=$(readlink -f "$0")
  echo "export PATH=\"/usr/local/bin:.:$PATH\""
  cat $script_path | sed '$d' | sed '$d'
}
