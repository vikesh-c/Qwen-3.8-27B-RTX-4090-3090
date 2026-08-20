# Qwen3.8-27B - RTX 4090 / RTX 3090 - llama.cpp -- llama-benchy ladder

- llama-benchy 0.4.0 (2026-08-20 07:48:16Z), latency 0.7 ms
- Model: `qwen3.8-27b` on llama.cpp `b10488` (context 163840, q4_0 KV, embedded MTP4, GPU vision)
- Workload: unique real book text, `--no-cache`, 3 runs x 2048 exact output tokens, temperature 0, single stream, per context: 4096, 8192, 16384, 32768, 65536, 131072
- GPU: NVIDIA GeForce RTX 4090 (24564 MiB total)

## Results

**Prefill** (cold, unique prompts -- mean of the measured runs):

| Context | tok/s | Std | Time to first token |
|---:|---:|---:|---:|
| 4,096 | 2126.7 | 4.9 | 1.9 s |
| 8,192 | 2121.8 | 6.2 | 3.9 s |
| 16,384 | 2098.4 | 39.0 | 7.8 s |
| 32,768 | 1998.2 | 8.2 | 16.4 s |
| 65,536 | 1764.8 | 3.3 | 37.1 s |
| 131,072 | 1408.3 | 0.2 | 93.1 s |

**Decode** (exact output length, mean of the measured runs):

| Context | tok/s | Std |
|---:|---:|---:|
| 4,096 | 85.8 | 16.8 |
| 8,192 | 93.0 | 12.3 |
| 16,384 | 78.9 | 4.1 |
| 32,768 | 89.5 | 14.1 |
| 65,536 | 64.1 | 12.4 |
| 131,072 | 54.2 | 1.8 |

Raw per-run distribution: [qwen3.8-27b-rtx4090-llama-cpp-mtp4-3x2048.json](qwen3.8-27b-rtx4090-llama-cpp-mtp4-3x2048.json)
