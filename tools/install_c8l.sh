# install_c8l.sh script to install the C8L toolchain
# first parameter is the branch to install from
# other parameters are the tools to install

BRANCH=${1:-main}
TOOLS=${@:2}

curl -o c8l https://raw.githubusercontent.com/chainloop-dev/labs/${BRANCH}/tools/c8l

chmod +x c8l
source <(./c8l source)

chainloop_bin_install c8l
chainloop_install $TOOLS

chainloop_bin_cache_in_dir .c8l_cache
