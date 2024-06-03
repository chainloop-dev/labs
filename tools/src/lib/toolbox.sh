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
  generic_install jq https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64
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