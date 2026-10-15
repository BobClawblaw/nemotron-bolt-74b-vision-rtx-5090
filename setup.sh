#!/usr/bin/env bash
#
# setup.sh: download the checkpoint at its pinned revision, check out the engine at its pinned commit and build it for
# sm_120. Idempotent; rerun after changing recipe.toml.
#
# Env: MODELS (./models), TF_SRC (./engine), XGRAMMAR (./xgrammar-<pin>), ZIG (zig on PATH, 0.17.0), NVCC (/usr/local/cuda/bin/nvcc)
#
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
pin() { python3 -c "import tomllib, sys; print(tomllib.load(open('recipe.toml', 'rb'))[sys.argv[1]][sys.argv[2]])" "$@"; }

MODELS="${MODELS:-$PWD/models}"
TF_SRC="${TF_SRC:-$PWD/engine}"
ZIG="${ZIG:-zig}"
NVCC="${NVCC:-/usr/local/cuda/bin/nvcc}"

"$ZIG" version | grep -qx "$(pin engine zig)" || { echo "need Zig $(pin engine zig) (ZIG=...)" >&2; exit 1; }

hf download "$(pin model repo)" --revision "$(pin model revision)" --local-dir "$MODELS/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB"

[ -d "$TF_SRC/.git" ] || git clone --branch "$(pin engine branch)" "$(pin engine repo)" "$TF_SRC"
git -C "$TF_SRC" fetch -q origin "$(pin engine branch)"
git -C "$TF_SRC" checkout -q "$(pin engine sha)"
(cd "$TF_SRC" && "$ZIG" build install native -Dnvcc="$NVCC" -Dsm="$(pin engine sm)" -Doptimize=ReleaseFast)

# structured output: libtfgrammar from xgrammar at the engine's pinned release, where the native server looks (../lib)
XGRAMMAR="${XGRAMMAR:-$PWD/xgrammar-$(pin grammar xgrammar)}"
[ -d "$XGRAMMAR/.git" ] || git clone -q --branch "$(pin grammar xgrammar)" --recurse-submodules https://github.com/mlc-ai/xgrammar "$XGRAMMAR"
(cd "$TF_SRC" && "$ZIG" build grammar -Dxgrammar="$XGRAMMAR" -Doptimize=ReleaseFast)
mkdir -p "$TF_SRC/zig-out/native/lib" && cp "$TF_SRC/zig-out/lib/libtfgrammar.so" "$TF_SRC/zig-out/native/lib/"
echo "built $TF_SRC/zig-out/native/bin/tensorfold-native at $(git -C "$TF_SRC" rev-parse --short HEAD)"
