# Source this file

if [ -z "$RUNNER_OS" -o -z "$MAKE_BIN" -o -z "$BUILD_ARCH" ]; then
    echo "Not all required environment variables set (RUNNER_OS, MAKE_BIN, BUILD_ARCH)!"
    exit -1
fi

if [ "$RUNNER_OS" = "Windows" ]; then
    BIN_SUFFIX=".exe"
    LIB_SUFFIX=".dll"
    MAKE_TYPE="MinGW"
elif [ "$RUNNER_OS" = "Linux" ]; then
    LIB_SUFFIX=".so"
    EXTRA_CMAKE_VARS="-DLIBOPENLIBM=$GITHUB_WORKSPACE/lib/libopenlibm-Linux-x86_64.a"
elif [ "$RUNNER_OS" = "macOS" ]; then
    LIB_SUFFIX=".dylib"
fi

ARTIFACTS_DIR="$PWD/artifacts"
mkdir -p $ARTIFACTS_DIR

RENODE_DIR="$PWD/VerilatorIntegrationLibrary"

# Usage: build SOURCE_DIR [OUT_NAME]
function build {
    pushd $1
    mkdir build
    cd build
    cmake -G "${MAKE_TYPE:-Unix} Makefiles" -DCMAKE_BUILD_TYPE=Release -DUSER_RENODE_DIR=$RENODE_DIR $EXTRA_CMAKE_VARS ..
    $MAKE_BIN VERBOSE=1

    # Check dependencies on Linux and Windows
    if [ "$RUNNER_OS" != "macOS" ]; then
        ldd "Vtop$BIN_SUFFIX"
    fi

    cp "Vtop$BIN_SUFFIX" "$ARTIFACTS_DIR/V${2:-$1}-$RUNNER_OS-$BUILD_ARCH-$GITHUB_RUN_ID$BIN_SUFFIX"
    cp "libVtop$LIB_SUFFIX" "$ARTIFACTS_DIR/libV${2:-$1}-$RUNNER_OS-$BUILD_ARCH-$GITHUB_RUN_ID$LIB_SUFFIX"
    popd
    rm -rf "$1/build"
}

# Script executables

pushd samples
for SAMPLE in *; do
    build $SAMPLE
done
popd

# Test executables

# Usage: build-modified-uartlite PATCH_NAME PATCH_ROOT
function build-modified-uartlite {
    PATCH=".github/scripts/tests/$1.patch"
    patch -d $2 -p1 <$PATCH
    # PATCH_NAME is passed as OUT_NAME
    build samples/uartlite $1
    patch -R -d $2 -p1 <$PATCH
}

# Connection Timeout
build-modified-uartlite sleep-after-1000-iters $RENODE_DIR

# Full connection inability
build-modified-uartlite wrong-ports $PWD

# Partial connection inability
build-modified-uartlite wrong-second-port $PWD

ls -lh $ARTIFACTS_DIR
