#!/usr/bin/env bash
#
# serve.sh: serve NVIDIA Nemotron 3.5 Bolt 74B-A9B (24 GB) with image input on TensorFold native (CUDA) on one RTX 5090.
# Foreground; the systemd unit runs it this way.
#
# Knobs (env): PORT (30000), HOST (0.0.0.0), CONTEXT (262144), PARALLEL (auto: two streams at 262144 with vision),
#   NAME (nemotron-bolt), MODELS (./models), TF_SRC (./engine), VISION (1: load the C-RADIO tower and take image_url
#   parts; 0: text only, more room for streams), PROMPT_CACHE_GIB (8: host memory for kept prompt states, at most
#   half of MemAvailable; 0 turns the cache off)
#
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
MODELS="${MODELS:-$PWD/models}"
TF_SRC="${TF_SRC:-$PWD/engine}"
vision=()
[ "${VISION:-1}" = 1 ] && vision=(--vision)
exec "$TF_SRC/zig-out/native/bin/tensorfold-native" serve "$MODELS/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB" \
  --name "${NAME:-nemotron-bolt}" \
  --host "${HOST:-0.0.0.0}" --port "${PORT:-30000}" \
  --context "${CONTEXT:-262144}" --parallel "${PARALLEL:-auto}" \
  --no-update-check "${vision[@]}" ${PROMPT_CACHE_GIB:+--prompt-cache-gib "$PROMPT_CACHE_GIB"}
