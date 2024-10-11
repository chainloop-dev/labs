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

chainloop_bin_install() {
  # it takes the list of paths and installs them in the CHAINLOOP_BIN_PATH
  # it creates the directory if it does not exist
  # it makes the files executable
  # make sure to detect the basename of the path and properly make the target file executable
  mkdir -p $CHAINLOOP_BIN_PATH
  for path in "$@"; do
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

install_chainloop_cli() {
  mkdir -p ${CHAINLOOP_TMP_DIR} $CHAINLOOP_BIN_PATH
  log "Installing Chainloop CLI"
  url_chainloop_cli="https://raw.githubusercontent.com/chainloop-dev/chainloop/eb53f4e8ce3c35251553efc77b7e04e792b2c992/docs/static/install.sh"
  if [ -n "${CHAINLOOP_VERSION}" ]; then
    curl -sfL "${url_chainloop_cli}" | bash -s -- --version v${CHAINLOOP_VERSION} --path $CHAINLOOP_BIN_PATH
  else
    curl -sfL "${url_chainloop_cli}" | bash -s -- --path $CHAINLOOP_BIN_PATH
  fi
  if [ $? -ne 0 ]; then
    log_error "Chainloop installation failed"
    return 1
  fi
}

###

# chainloop_install takes the list of tools and installs them with functions below install_${name}
chainloop_install() {
  for tool in "$@"; do
    if ! "install_${tool}" ;  then
      return 1
    fi
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

spdx2cyclonedx() {
  spdx_file=$1
  cyclonedx_file=$2
  syft convert "${spdx_file}" -o cyclonedx-json="${cyclonedx_file}"
  if [ $? -ne 0 ]; then
    log_error "SPDX to CycloneDX conversion failed"
    return 1
  fi
}

###

chainloop_attestation_init() {
  log "Initializing Chainloop Attestation"
  CR_VALUE=""
  if [ -n "${CHAINLOOP_CONTRACT_REVISION}" ]; then
    CR_VALUE="--contract-revision ${CHAINLOOP_CONTRACT_REVISION}"
  fi
  WF_NAME_VALUE=""
  if [ -n "${CHAINLOOP_WORKFLOW_NAME}" ]; then
    WF_NAME_VALUE="--workflow ${CHAINLOOP_WORKFLOW_NAME}"
  fi
  PROJECT_NAME_VALUE=""
  if [ -n "${CHAINLOOP_PROJECT_NAME}" ]; then
    PROJECT_NAME_VALUE="--project ${CHAINLOOP_PROJECT_NAME}"
  fi
  r=$(chainloop attestation init -f --remote-state --output json $CR_VALUE $WF_NAME_VALUE $PROJECT_NAME_VALUE)
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
  if [ -n "${CHAINLOOP_SIGNING_KEY}" ]; then
    log "  with CHAINLOOP_SIGNING_KEY"
    tmp_key="${CHAINLOOP_TMP_DIR}/key"
    mkdir -p "${CHAINLOOP_TMP_DIR}"
    echo "${CHAINLOOP_SIGNING_KEY}" > "$tmp_key"
  fi
  if [ -n "${CHAINLOOP_SIGNING_KEY_PATH}" ]; then
    log "  with CHAINLOOP_SIGNING_KEY_PATH"
    tmp_key="${CHAINLOOP_SIGNING_KEY_PATH}"
  fi

  tmp_key_value=""
  if [ -n "$tmp_key" ]; then
    tmp_key_value="--key $tmp_key"
  fi

  # chainloop attestation push --key env://CHAINLOOP_SIGNING_KEY
  if chainloop attestation push "$tmp_key_value" --output json --remote-state --attestation-id "${CHAINLOOP_ATTESTATION_ID}" > c8-push.txt; then
    log "Attestation Process Completed Successfully"
    cat c8-push.txt
    rm -f "$tmp_key"
  else
    exit_code=$?
    log_error "Attestation Process Failed"
    cat c8-push.txt
    rm -f "$tmp_key"
    return $exit_code
  fi
}

chainloop_summary() {
  tmpfile=$(prepare_tmp_file report.txt)
  if [ $? -ne 0 ]; then
    log $tmpfile
    return 1
  fi
  echo -e "## Great job!\n\nYou are making SecOps and Compliance teams really happy. Keep up the good work!\n" >> $tmpfile

  digest=""
  if [ -f c8-push.txt ]; then
    digest=$(cat c8-push.txt | jq -r '.digest')
    if [ $? -ne 0 ]; then
      log_error "Failed to get digest from c8-push.txt"
      return 1
    fi
    echo "**[Chainloop Trust Report]( https://app.chainloop.dev/attestation/${digest} )**" >> "$tmpfile"
  fi
  if [ -f c8-status.txt ] ; then
    echo "\`\`\`" >> "$tmpfile"
    cat c8-status.txt >> "$tmpfile"
    echo "\`\`\`" >> "$tmpfile"
  fi
  cat "$tmpfile"
  rm "$tmpfile"
}

chainloop_summary_on_failure() {
  log "Generating Summary on Failure"
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

###

chainloop_generate_github_summary() {
  chainloop_summary >>$GITHUB_STEP_SUMMARY
}

chainloop_generate_github_summary_on_failure() {
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
