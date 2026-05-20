# go-vet.ps1 — PostToolUse hook
# Runs `go vet ./...` whenever a .go file is edited by the agent.
# Exit 2 on vet failure to surface errors as a blocking message.

$raw = [Console]::In.ReadToEnd()
try { $data = $raw | ConvertFrom-Json } catch { exit 0 }

$filePath = $data.tool_input.filePath
if (-not $filePath -or $filePath -notlike "*.go") { exit 0 }

$out = & go vet ./... 2>&1
if ($LASTEXITCODE -ne 0) {
    @{ systemMessage = "go vet failed:`n$($out -join "`n")" } | ConvertTo-Json -Compress
    exit 2
}
