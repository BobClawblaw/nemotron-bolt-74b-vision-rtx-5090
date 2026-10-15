# Nemotron 3.5 Bolt 74B-A9B with image input and a 262k window on one RTX 5090

This recipe serves NVIDIA's [Nemotron-3.5-Bolt-74B-A9B-24GB](https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB) on a single
RTX 5090 (sm_120, 32 GB). It runs on [TensorFold](https://github.com/ashhart/TensorFold)'s native Zig engine on CUDA:
- text and images in one OpenAI-compatible API (`image_url` parts);
- the model's 262,144-token window, two streams at once, with the vision tower loaded;
- kept prompt states in pinned host memory: a chat's next turn reads only what is new;
- structured output (JSON schema, regex, choice, grammar) and tool calls;
- a systemd unit.

The engine is the [`nemotron-bolt-5090`](https://github.com/BobClawblaw/TensorFold/tree/nemotron-bolt-5090) branch.
That is the upstream PR branch [`nemotron-bolt`](https://github.com/BobClawblaw/TensorFold/tree/nemotron-bolt) plus an
image decoder. Upstream's shared decoder (`core/picture`, libjpeg-turbo) arrives with TensorFold 1.0.12; until then
this branch decodes JPEG and PNG with stb_image.

## What the engine adds for Bolt

Bolt is NVIDIA's Star Elastic compression of Nemotron 3.5 Super VL 120B-A12B. Its checkpoint differs from the
Nemotron 3.5 Lightning that TensorFold already served on CUDA in several ways:
- **Layers:**
  - 88 of them: 40 Mamba-2, 40 MoE, 8 attention.
  - Each MoE layer has its own expert count (240 to 496), width (1536 to 2560) and top-9 router (`nemotron_h_puzzle`).
- **LatentMoE:**
  - The routed experts work in a 1024-wide latent: `fc1_latent_proj` in, their weighted sum, `fc2_latent_proj` out.
  - A 5376-wide shared expert reads the full-width rows.
- **Weights:** ModelOpt mixed precision, stored as ggml blocks in safetensors.
  - IQ2_XXS experts, 2.06 bits a weight.
  - Q8_0 latent, attention and output projections.
  - NVFP4 Mamba projections and a bf16 embedding.
  - The engine reads the ggml blocks with its own CUDA kernels (`zig/kernels/cuda/ggml.cu`). They are repacked into 16-column tiles at load, and the expert kernel fuses relu².
- **Vision:**
  - C-RADIO v4-H: 32 blocks, 16 heads of 80, CPE position embedding, 10 prefix tokens dropped.
  - Then a pixel-shuffle projector.
  - One tile per image at its own size (16-pixel patches, up to 13,312 patches, which is 3,328 image tokens).

## Against vLLM

The vLLM reference is NVIDIA's pinned nightly (`vllm/vllm-openai:nightly-77154ca6116ae34cbfe314beef1016bde9b63989`)
with the model card's flags, minus the drafter, on the same card.

**Agreement:** greedy, on six text prompts:
- Four replies are word for word identical, including a summary of a 4,084-token document.
- The other two part where vLLM's own two best tokens are 0.25 and 0.5 nats apart. On the first of these, a fp32
  PyTorch reference of the model (`tools/zig/bolt_reference.py` in the engine) picks the same token as this engine:
  ` von` −0.715 against ` eines` −0.831.

**Images:** both prompt token counts equal vLLM's (1,596 and 1,589). The first token is the same within 0.05 logprob,
and the text read from the images is identical.

| | this recipe | vLLM nightly, model card flags, no drafter |
|---|---:|---:|
| Decode, one stream, short prompts | **150 tok/s** | about 25 tok/s |

## Measured on this card

RTX 5090 (32 GB), engine `b2ec378d`, 262,144-token window, two streams, vision loaded, an 8 GiB host prompt cache. At
startup the engine holds 28.7 GB of the card.

The full plan of the [recipe harness](https://github.com/BobClawblaw/recipe-harness) ran on 2026-10-15. The files are in
[`evidence/2026-10-15-full/`](evidence/2026-10-15-full/).

**Decode** (`bench/ruler.py`, one user):

| | prose | code | structured | list | first token |
|---|---:|---:|---:|---:|---:|
| fresh | 149.7 | 149.6 | 150.1 | 149.7 | 0.03 s |
| after the suite | 149.3 | 149.2 | 149.7 | 149.3 | 0.03 s |

**Quality** (thinking off):

| Check | Result |
|---|---|
| GSM8K | 241/250 |
| HumanEval (pass@1, sandboxed) | 153/164 |
| MMLU (57 subjects × 6) | 279/342 |
| IFEval (loose / strict) | 120/150 / 114/150 |
| MGSM | 190/240 (de 27, es 29, fr 27, ja 26, zh 27, ru 28, sw 9, bn 17 of 30) |
| Tools | 58/60 |
| JSON | 30/30 |
| Long context | 55/55: needles 15/15 to 222k, spread facts 10/10 at 28k, 56k, 113k and 223k; prefill at least 4,500 tok/s |
| Vision | 12/12 |
| Repetition | 8/8 |

**Exactness and serving:**

| Check | Result |
|---|---|
| Concurrent streams equal alone | 12/12 |
| Streamed equal non-streamed | 4/4 |
| Seeded sampling equal on repeat | 9/9 |
| Soak: 3 chats × 20 turns resuming ~6k-token kept states beside a decoding stream | 60/60 equal alone, 60/60 resumed |
| Prompt cache turns | resumed = again = cold; first token 0.053 s resumed against 0.134 s cold |
| Structured output (json_object, json_schema, guided_json, regex, choice, grammar; greedy, sampled, thinking) | 18/18 obey; a bad regex is a 400 |
| Capacity: 6 long prompts at once, then a short request | 6/6 answered, short request 200 |
| Behaviour (multiturn, stop, thinking, copy, max-tokens) | all pass |

## Setup

Requirements:
- Linux, an RTX 5090 (or another sm_120 card with 32 GB), the NVIDIA driver and CUDA 13.
- Zig 0.17.0, `hf` (huggingface_hub) and git.
- About 40 GB of disk and 16 GB of free host memory for the prompt cache.

```bash
git clone https://github.com/BobClawblaw/nemotron-bolt-74b-vision-rtx-5090.git && cd nemotron-bolt-74b-vision-rtx-5090
./setup.sh          # the checkpoint at its pinned revision, the engine at its pinned commit, libtfgrammar
./serve.sh          # foreground; port 30000
```

**Knobs** (environment, for `serve.sh` or a systemd drop-in):

| Variable | Default | |
|---|---|---|
| `CONTEXT` | 262144 | the window; two streams fit at 262144 with vision |
| `PARALLEL` | auto | streams at once |
| `VISION` | 1 | 0: text only, more room for streams |
| `PROMPT_CACHE_GIB` | 8 | host memory for kept prompt states, at most half of MemAvailable; 0 turns the cache off |
| `PORT`, `HOST`, `NAME` | 30000, 0.0.0.0, nemotron-bolt | |

**systemd:** [`systemd/tensorfold-bolt.service`](systemd/tensorfold-bolt.service). Set its User, Group and paths, then
`sudo systemctl daemon-reload && sudo systemctl enable --now tensorfold-bolt`.

**A request with an image:**

```bash
curl -s localhost:30000/v1/chat/completions -H 'content-type: application/json' -d '{
  "model": "nemotron-bolt", "chat_template_kwargs": {"enable_thinking": false},
  "messages": [{"role": "user", "content": [
    {"type": "image_url", "image_url": {"url": "data:image/png;base64,'"$(base64 -w0 photo.png)"'"}},
    {"type": "text", "text": "What does this image show?"}]}]}'
```

Thinking is on by default, as the chat template has it. Send `"chat_template_kwargs": {"enable_thinking": false}` to
turn it off. NVIDIA recommends temperature 1.0 and top_p 0.95 for sampled replies.

## Notes

- **No drafts:** the checkpoint has no MTP head. NVIDIA's LiLiCorr DFlash drafter is not read by TensorFold yet.
- **Video:** video inputs are refused for now.
- **Prompt cache and images:** image prompts are never kept or resumed, because every image's placeholder ids are the
  same. Text turns resume.

## License

MIT for this repository. The model (OpenMDW-1.1) and TensorFold carry their own licenses.
