# setup_file() {
# }

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )/.." >/dev/null 2>&1 && pwd )"
    export PATH="$DIR/:$PATH:/usr/local/bin/chainloop_bin"
    export DO_NOT_TRACK=1
}

@test "can run c8l script" {
    run c8l
    assert_failure
}

@test "can run c8l script --version" {
    run c8l --version
    assert_success
}

@test "fails to run c8l adasd" {
    run c8l adasd
    # [ "${status}" -ne 0 ]
    assert_failure
}

@test "can detect when chainloop is NOT in PATH" {
    run bash -c "c8l r is_chainloop_in_path"
    assert_output --regexp ".*chainloop is not in PATH.*"
    # assert_line --index 0 --regexp ".*chainloop is not in PATH.*"
}

@test "can install chainloop cli using install_chainloop_cli" {
    run bash -c "source <(./c8l source) > /dev/null; chainloop_install chainloop_cli"
    assert_success
}


###
### Integration tests
###

# TODO: move to integration tests
@test "can run c8l_install.sh" {
   cd /tmp
   run bash $DIR/install_c8l.sh main chainloop_cli cosign
   assert_success
}

@test "can install yq" {
    run bash -c "source <(./c8l source); install_yq"
    assert_success
}

@test "can detect chainloop in PATH" {
    run bash -c "source <(./c8l source); is_chainloop_in_path"
    assert_success
}

# Abats test_tags=bats:focus
@test "full attestation flow" {
    export CHAINLOOP_WORKFLOW_NAME="labs-tests"
    export CHAINLOOP_PROJECT_NAME="labs"
    cp ./c8l /tmp
    cd /tmp
    mkdir -p .c8l_cache

    c8l r "chainloop_install yq jq cosign chainloop_cli "
    c8l r "chainloop_attestation_init ; chainloop_save_env_to_cache .c8l_cache CHAINLOOP_ATTESTATION_ID"

    echo -e "chainloop-labs-tests:\n  - path: ./c8l" > .chainloop.yml
    # yq -p yaml -o json .chainloop.yml > .chainloop.json

    source <(c8l r 'chainloop_restore_env_all_from_cache .c8l_cache | grep export')
    # chainloop_attestation_add_from_yaml demo
    chainloop attestation add --value ./c8l --kind ARTIFACT --remote-state --attestation-id ${CHAINLOOP_ATTESTATION_ID}

    c8l r chainloop_attestation_status
    run c8l r chainloop_attestation_push
    assert_success

    digest=$(cat c8-push.txt | jq -r '.digest')
    run bash -c "c8l r chainloop_summary"
    assert_output --regexp ".*attestation\/${digest}.*"

    ###
    # use key pair
    c8l r "chainloop_attestation_init ; chainloop_save_env_to_cache .c8l_cache CHAINLOOP_ATTESTATION_ID"
    source <(c8l r 'chainloop_restore_env_all_from_cache .c8l_cache | grep export')
    chainloop attestation add --value ./c8l --kind ARTIFACT --remote-state --attestation-id ${CHAINLOOP_ATTESTATION_ID}
    CHAINLOOP_USE_INSECURE_KEY=true
    run bash -c "c8l r chainloop_attestation_push"
    assert_success
}
