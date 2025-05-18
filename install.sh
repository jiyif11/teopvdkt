#!/bin/bash
set -e  
git submodule update --init --recursive

# default backend
DEV="cuda"

# parse --dev argument
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dev) DEV="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done
export DEV_BACKEND="$DEV"
echo "Selected backend: $DEV_BACKEND"

# clear build dirs
rm -rf build
rm -rf *.egg-info
rm -rf csrc/build
rm -rf csrc/ktransformers_ext/build
rm -rf csrc/ktransformers_ext/cuda/build
rm -rf csrc/ktransformers_ext/cuda/dist
rm -rf csrc/ktransformers_ext/cuda/*.egg-info
rm -rf ~/.ktransformers
echo "Installing python dependencies from requirements.txt"
pip install torch -i https://download.pytorch.org/whl/cu126
pip install -r requirements-local_chat.txt
pip install -r ktransformers/server/requirements.txt

echo "Installing ktransformers"
export USE_BALANCE_SERVE=1
patch -sr /dev/null -p1 --batch --forward third_party/llama.cpp/ggml-common.h < ggml-common.patch || true
KTRANSFORMERS_FORCE_BUILD=TRUE pip install -v . --no-build-isolation

SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
echo "Copying thirdparty libs to $SITE_PACKAGES"
cp -a csrc/balance_serve/build/third_party/prometheus-cpp/lib/libprometheus-cpp-*.so* $SITE_PACKAGES/
patchelf --set-rpath '$ORIGIN' $SITE_PACKAGES/sched_ext.cpython*

if [[ "$DEV_BACKEND" == "cuda" ]]; then
    echo "Installing custom_flashinfer for CUDA backend"
    pip install third_party/custom_flashinfer/
fi

echo "Installation completed successfully"