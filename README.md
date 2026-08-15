# Qwen3.8-27B · RTX 4090 / RTX 3090 · llama.cpp

A single-GPU serving recipe for [Qwen3.8-27B](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF) (Q4_K_M) on an RTX 4090 or RTX 3090 (24 GiB): 163,840-token context, embedded MTP speculative decoding, GPU vision, and thinking control. One command downloads everything, one command starts the server.

```powershell
$env:LOCAL_LLM_ROOT = 'C:\local-llm'
.\scripts\bootstrap.ps1   # HF auth → model + template + latest llama.cpp, SHA-256 verified
.\scripts\start.ps1       # server up on 127.0.0.1:8080
```

## Config

| | |
|---|---|
| Model | `Qwen3.8-27B-Q4_K_M.gguf` |
| Context | 163,840 tokens, q4_0 KV cache, batch 256 |
| Speculative decoding | embedded MTP head, max 2 draft tokens; llama.cpp f16 draft KV defaults |
| Vision | enabled, `mmproj-F16.gguf`, GPU offload |
| Chat template | Hash-pinned Froggeric v22 fixed template, with the GGUF-embedded Qwen3.8 template as fallback (thinking on + preserved by default; per-request `enable_thinking:false` / `reasoning_effort: low\|medium\|xhigh` in `chat_template_kwargs`) |
| API | authenticated loopback `127.0.0.1:8080`; the established key under `%LOCALAPPDATA%\Qwen3.8-27B-24GB\llama-server.key` is reused |
| llama.cpp runtime | Latest stable at bootstrap time, digest-verified (CUDA); **b10430** is the tested baseline — re-run benchmarks if you use a newer build |

The operational profile is 163,840 tokens. Benchmark requests stop at 160,000
prompt tokens so the chat wrapper and completion fit the slot.

## Benchmarking

The repository includes three benchmark runners for decode, cold prefill, and
near-limit capacity checks. Measurement receipts are intentionally not included
in this initial recipe commit; run the scripts against the exact runtime and
template you install before publishing or comparing performance numbers.

## Repository map

```
scripts/    bootstrap, start, stop, status, probe, context-capacity, validate
benchmarks/ bench (decode ladder), prefill, prefill-near-limit
config/     profile templates (copy → profile.json)
tests/      process discovery check
```

## Install notes

- **Hugging Face auth is required** for the model download — bootstrap detects the `hf` CLI, installs it if missing, and walks you through login before downloading.
- Bootstrap installs the **latest stable** llama.cpp with the release's published SHA-256 digests; it refuses to proceed if digests are missing. The live recipe was verified with b10430; run the included benchmarks if you use a newer build.
- Bootstrap also downloads the Froggeric v22 chat template from immutable revision `9f14778` and verifies SHA-256 before use; if the file is later absent, start falls back to the model's embedded template.
- The server keeps llama.cpp prompt RAM cache at its runtime default and leaves MTP draft KV at the llama.cpp f16 default.
- Rollback/second model: stop, point `config/profile.json` at another runtime/model, start. One model at a time.

## License

MIT for repository material. Model weights, projector, and llama.cpp binaries retain upstream terms; this repo does not redistribute them.
