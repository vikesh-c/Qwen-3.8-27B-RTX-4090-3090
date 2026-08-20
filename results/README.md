# Measured receipts

Receipts are JSON + Markdown pairs produced by the pinned
[llama-benchy](https://github.com/eugr/llama-benchy) 0.4.0 runner. The JSON is
the raw per-run distribution; the Markdown is the human-readable prefill and
decode summary.

The canonical receipt is
`qwen3.8-27b-rtx4090-llama-cpp-mtp4-3x2048.{json,md}`. It was measured on the
RTX 4090 with the UD-Q4_K_M artifact, llama.cpp b10488, 163,840-token context,
q4_0 main KV, GPU vision, embedded MTP4, single concurrency, and the Froggeric
v22 template. It contains six prompt rungs through 131,072 tokens (128k),
three independent runs per rung, and exactly 2,048 generated tokens per run.

The workload uses unique real book text and `--no-cache`, so the measurements
do not reuse a prefix cache. Reproduce the receipt with:

```powershell
.\benchmarks\install-llama-benchy.ps1
.\benchmarks\bench.ps1
```

The runner never starts or restarts the server. It requires the configured
loopback endpoint to already be healthy and writes receipts under `results\`.
