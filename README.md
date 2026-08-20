# Qwen3.8-27B - RTX 4090 / RTX 3090 - llama.cpp

A single-GPU serving recipe for [Qwen3.8-27B](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF) (Unsloth Dynamic 3.0 UD-Q4_K_M) on an RTX 4090 or RTX 3090 (24 GiB): 163,840-token context, embedded MTP speculative decoding, GPU vision, Froggeric v22 chat templating, and thinking control.

```powershell
$env:LOCAL_LLM_ROOT = 'C:\local-llm'
.\scripts\bootstrap.ps1   # HF auth -> model + template + latest llama.cpp, SHA-256 verified
.\scripts\start.ps1       # server on 127.0.0.1:8080
```

## Config

| | |
|---|---|
| Model | `Qwen3.8-27B-UD-Q4_K_M.gguf` |
| Context | 163,840 tokens, q4_0 KV cache, batch 256 |
| Speculative decoding | Embedded MTP head, max 4 draft tokens; llama.cpp f16 draft KV defaults |
| Vision | Enabled, `mmproj-F16.gguf`, GPU offload |
| Chat template | Hash-pinned Froggeric v22 fixed template; thinking and preservation on by default |
| API | Authenticated loopback `127.0.0.1:8080`; the established protected key is reused |
| llama.cpp runtime | Latest stable at bootstrap time, digest-verified (CUDA); b10488 is the measured baseline in `results/` |

The operational profile is 163,840 tokens. Benchmark requests stop at 160,000
prompt tokens when using the near-limit capacity runner so the chat wrapper and
completion fit the slot.

## Benchmarking

The primary performance ladder follows the same external, engine-agnostic
contract as the companion SGLang and oMLX recipes: pinned `llama-benchy` 0.4.0,
unique real book text, `--no-cache`, three runs per context, and exactly 2,048
generated tokens. It measures both cold prefill and decode from the same
OpenAI-compatible request shape at 4K, 8K, 16K, 32K, 64K, and 128K.

```powershell
.\benchmarks\install-llama-benchy.ps1
.\benchmarks\bench.ps1
```

The canonical MTP4 receipt is [the raw JSON](results/qwen3.8-27b-rtx4090-llama-cpp-mtp4-3x2048.json)
with its [Markdown summary](results/qwen3.8-27b-rtx4090-llama-cpp-mtp4-3x2048.md).
The separate `prefill.ps1`, `prefill-near-limit.ps1`, and
`scripts/context-capacity.ps1` runners remain available for llama.cpp-specific
500-token decode and 160K cold-capacity checks. Benchmark runners never start
or restart the server.

## Repository map

```
scripts/    bootstrap, start, stop, status, probe, context-capacity, validate
benchmarks/ llama-benchy ladder, installer/parser, prefill, near-limit checks
config/     profile templates (copy -> profile.json)
results/    llama-benchy JSON + Markdown receipts
tests/      process discovery and llama-benchy parser checks
```

## Install notes

- Hugging Face authentication is required for the model download. Bootstrap detects the `hf` CLI, installs it if missing, and guides login.
- Bootstrap installs the latest stable llama.cpp with the release's published SHA-256 digests and records the exact build in the external runtime manifest.
- Bootstrap downloads the Froggeric v22 chat template from an immutable revision and verifies its SHA-256 before use.
- The server keeps llama.cpp prompt RAM caching at its runtime default and leaves MTP draft KV at the llama.cpp f16 default.
- The canonical live setup is loopback-only, one slot, authenticated, and detached under the scheduled supervisor.

## License

MIT for repository material. Model weights, projector, and llama.cpp binaries retain upstream terms; this repository does not redistribute them.
