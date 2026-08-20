# bench.ps1 -- combined prefill + decode ladder via llama-benchy.
#
#   .\benchmarks\bench.ps1                          # full 6-rung ladder, 3 runs
#   .\benchmarks\bench.ps1 -Contexts 4096,65536    # subset of rungs
#
# This is the same engine-agnostic benchmark contract used by the companion
# SGLang and oMLX recipes: unique prompts, --no-cache, three runs per rung,
# and exactly 2,048 generated tokens. The server must already be running;
# this runner never launches, restarts, or changes it.

[CmdletBinding()]
param(
    [int[]]$Contexts = @(4096, 8192, 16384, 32768, 65536, 131072),
    [int]$Runs = 3,
    [int]$OutputTokens = 2048,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\common.ps1')
Import-Module (Join-Path $PSScriptRoot 'Parse-LlamaBenchyResults.psm1') -Force

if (@($Contexts).Count -eq 0) { throw 'Contexts must not be empty.' }
if (@($Contexts | Sort-Object -Unique).Count -ne @($Contexts).Count) { throw 'Contexts must not contain duplicates.' }
$Contexts = @($Contexts | Sort-Object)
foreach ($c in $Contexts) { if ($c -lt 1) { throw "Context $c is not a positive token count." } }
if ($Runs -lt 1 -or $Runs -gt 10) { throw 'Runs must be between 1 and 10.' }
if ($OutputTokens -lt 16) { throw 'OutputTokens must be at least 16.' }

$loaded = Read-RecipeConfig
$profile = $loaded.Data
$bindHost = [string](Get-RecipeProperty $profile 'host' '127.0.0.1')
Assert-RecipeLoopback -BindHost $bindHost
$port = [int](Get-RecipeProperty $profile 'port' 8080)
Assert-RecipePort -Port $port
$modelId = [string](Get-RecipeProperty $profile 'modelId' 'qwen3.8-27b')
$context = [int](Get-RecipeProperty $profile 'context' 163840)
foreach ($c in $Contexts) {
    if ($c + $OutputTokens -gt $context) {
        throw "Rung $c plus $OutputTokens output tokens exceeds the $context-token context."
    }
}

$repoRoot = Get-RecipeRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot ("results\qwen3.8-27b-rtx4090-llama-cpp-mtp4-{0}x{1}.json" -f $Runs, $OutputTokens)
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null

$serverBase = "http://${bindHost}:${port}"
$apiBase = "$serverBase/v1"
$key = Get-RecipeKey -Config $profile
$headers = Get-RecipeHeaders -Key $key
try {
    $health = Invoke-RestMethod -Uri "$serverBase/health" -Headers $headers -TimeoutSec 15 -ErrorAction Stop
    if ([string]$health.status -ne 'ok') { throw 'health status was not ok' }
} catch {
    throw "llama.cpp server is not healthy at $serverBase. Run .\scripts\start.ps1 first."
}
$models = Invoke-RestMethod -Uri "$apiBase/models" -Headers $headers -TimeoutSec 15 -ErrorAction Stop
$ids = @($models.data | ForEach-Object { [string]$_.id })
if ($ids -notcontains $modelId) { throw "Model '$modelId' is not advertised ($($ids -join ', '))." }

$runtimeTag = 'unknown'
try {
    $manifest = Get-Content -LiteralPath (Get-RecipeRuntimeManifestPath $profile) -Raw | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace([string]$manifest.tag)) { $runtimeTag = [string]$manifest.tag }
} catch { }

$uvx = Get-Command uvx -ErrorAction SilentlyContinue
if ($null -eq $uvx) { throw 'uvx not found. Run .\benchmarks\install-llama-benchy.ps1 first.' }

$uvArgs = @(
    '--from', 'llama-benchy==0.4.0', 'llama-benchy',
    '--base-url', $apiBase,
    '--api-key', $key.Value,
    '--model', $modelId,
    '--tokenizer', 'Qwen/Qwen3.8-27B',
    '--pp'
)
$uvArgs += @($Contexts | ForEach-Object { [string]$_ })
$uvArgs += @(
    '--tg', [string]$OutputTokens,
    '--depth', '0',
    '--runs', [string]$Runs,
    '--exact-tg',
    '--no-cache',
    '--extra-body', 'temperature=0',
    '--extra-body', 'return_token_ids=false',
    '--save-result', $OutputPath,
    '--format', 'json'
)

$gpuBefore = Get-RecipeGpuInfo
$progressLog = Join-Path $env:TEMP "llama-benchy-progress-$([Guid]::NewGuid().ToString('N')).txt"
Write-Host "Server: healthy at $apiBase (model '$modelId', context $context)"
Write-Host "Ladder: $([string]::Join(', ', @($Contexts | ForEach-Object { [string]$_ }))) x $Runs runs x $OutputTokens output tokens"
Write-Host 'Running llama-benchy; the server is never restarted by this script...'

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $uvx.Source @uvArgs 2>&1 | Tee-Object -FilePath $progressLog
    $benchCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $prevEap
}
if ($benchCode -ne 0) { throw "llama-benchy exited with code $benchCode. Progress: $progressLog" }
$gpuAfter = Get-RecipeGpuInfo

$doc = Read-LlamaBenchyJson -Path $OutputPath
$rungs = @(Get-LlamaBenchyRungs -Document $doc)
if ($rungs.Count -ne $Contexts.Count) { throw "Receipt has $($rungs.Count) measured rungs; expected $($Contexts.Count)." }
for ($i = 0; $i -lt $Contexts.Count; $i++) {
    $rung = $rungs[$i]
    if ([Math]::Abs([int]$rung.promptTokens - $Contexts[$i]) -gt 512) { throw "Receipt rung $($rung.promptTokens) is not near requested $($Contexts[$i])." }
    if ([int]$rung.runsMeasured -ne $Runs) { throw "Receipt rung $($rung.promptTokens) has $($rung.runsMeasured) runs; expected $Runs." }
    if ([double]$rung.prefillTpsMean -le 0 -or [double]$rung.decodeTpsMean -le 0) { throw "Receipt rung $($rung.promptTokens) has non-positive throughput." }
}

$mdPath = [IO.Path]::ChangeExtension($OutputPath, '.md')
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Qwen3.8-27B - RTX 4090 / RTX 3090 - llama.cpp -- llama-benchy ladder')
$lines.Add('')
$lines.Add([string]::Format('- llama-benchy {0} ({1}), latency {2} ms', $doc.version, $doc.timestamp, [math]::Round([double]$doc.latency_ms, 1)))
$lines.Add([string]::Format('- Model: `{0}` on llama.cpp `{1}` (context {2}, q4_0 KV, embedded MTP4, GPU vision)', $modelId, $runtimeTag, $context))
$lines.Add([string]::Format('- Workload: unique real book text, `--no-cache`, {0} runs x {1} exact output tokens, temperature 0, single stream, per context: {2}', $Runs, $OutputTokens, ($Contexts -join ', ')))
if ($null -ne $gpuBefore) { $lines.Add([string]::Format('- GPU: {0} ({1} MiB total; before {2} MiB used, after {3} MiB used)', $gpuBefore.name, $gpuBefore.totalMiB, $gpuBefore.usedMiB, $gpuAfter.usedMiB)) }
$lines.Add('')
$lines.Add((Convert-RungsToMarkdown -Rungs $rungs -Title 'Results'))
$lines.Add('')
$lines.Add('Raw per-run distribution: [' + [IO.Path]::GetFileName($OutputPath) + '](' + [IO.Path]::GetFileName($OutputPath) + ')')
[IO.File]::WriteAllText($mdPath, ($lines -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))

Write-Host ''
Write-Host ("Rung ladder (mean of {0} run(s)):" -f $Runs)
Write-Host ('{0,8} | {1,10} | {2,10} | {3,10}' -f 'context', 'prefill t/s', 'decode t/s', 'TTFT s')
foreach ($r in $rungs) {
    $ttftS = [math]::Round([double]$r.ttfrMsMean / 1000.0, 1)
    Write-Host ('{0,8} | {1,10} | {2,10} | {3,10}' -f ([string]::Format('{0:N0}', $r.promptTokens)), ('{0:N1}' -f $r.prefillTpsMean), ('{0:N1}' -f $r.decodeTpsMean), ('{0:N1}' -f $ttftS))
}
Write-Host "Receipt: $OutputPath"
Write-Host "Summary: $mdPath"
Remove-Item -LiteralPath $progressLog -Force -ErrorAction SilentlyContinue
exit 0
