# setup_file() {
# 
# }

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )/.." >/dev/null 2>&1 && pwd )"
    PATH="$DIR/:$PATH" 
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
    run bash -c "source <(./c8l source) > /dev/null; is_chainloop_in_path"
    assert_output --regexp ".*chainloop is not in PATH.*"
    # assert_line --index 0 --regexp ".*chainloop is not in PATH.*"
}

###
### Integration tests
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