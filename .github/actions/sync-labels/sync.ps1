<#
.SYNOPSIS
    Create every label the repository's dependabot.yml references.

.DESCRIPTION
    Dependabot will not create labels that are named explicitly under `labels:`.
    When one is missing it refuses the whole update with

        The following labels could not be found: `dependencies`, `nuget`.

    and opens no pull request, so the repo quietly stops receiving dependency
    updates until someone notices. This script closes that gap by reading the
    names straight out of the config and ensuring each one exists.

    `gh label create --force` updates an existing label's colour and description
    rather than failing, so running this repeatedly is safe and also repairs a
    label somebody edited by hand.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $LabelStyles,
    [Parameter(Mandatory)] [string] $FallbackColor
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "No $ConfigPath in this repository - nothing to sync."
    exit 0
}

try {
    $styles = $LabelStyles | ConvertFrom-Json
}
catch {
    Write-Host "::error::label-styles is not valid JSON: $($_.Exception.Message)"
    exit 1
}

# Line-based rather than a real YAML parse: the only thing we need is the
# `labels:` values, and pulling in a YAML module for that would be a heavier
# dependency than the problem warrants. Handles both the inline flow form
# (labels: ["a", "b"]) and the block sequence form.
$names = [System.Collections.Generic.List[string]]::new()

function Add-Name([string] $raw) {
    $n = $raw.Trim().Trim('"', "'").Trim()
    if ($n -and -not $names.Contains($n)) { $names.Add($n) }
}

$inBlock = $false
$blockIndent = 0

foreach ($line in Get-Content -LiteralPath $ConfigPath) {
    # Strip comments, but not inside a quoted string. Label names never contain
    # '#', so a plain split is good enough here.
    $code = ($line -split '#', 2)[0]

    if ($code -match '^(?<indent>\s*)labels:\s*\[(?<items>.*)\]\s*$') {
        foreach ($item in $Matches['items'] -split ',') { Add-Name $item }
        $inBlock = $false
        continue
    }

    if ($code -match '^(?<indent>\s*)labels:\s*$') {
        $inBlock = $true
        $blockIndent = $Matches['indent'].Length
        continue
    }

    if ($inBlock) {
        if ($code -match '^(?<indent>\s*)-\s*(?<value>.+?)\s*$' -and
            $Matches['indent'].Length -gt $blockIndent) {
            Add-Name $Matches['value']
        }
        elseif ($code.Trim()) {
            $inBlock = $false
        }
    }
}

if ($names.Count -eq 0) {
    Write-Host "$ConfigPath references no labels - nothing to sync."
    exit 0
}

Write-Host "Labels referenced by ${ConfigPath}: $($names -join ', ')"

$failed = @()

foreach ($name in $names) {
    $style = $styles.PSObject.Properties[$name]
    $color = if ($style) { $style.Value.color } else { $FallbackColor }
    $desc = if ($style) { $style.Value.description } else { "Used by Dependabot" }

    gh label create $name --repo $env:GITHUB_REPOSITORY --force `
        --color $color --description $desc

    if ($LASTEXITCODE -ne 0) {
        $failed += $name
        Write-Host "::warning::Could not sync label '$name'."
    }
    else {
        Write-Host "  synced $name (#$color)"
    }
}

if ($failed.Count -gt 0) {
    Write-Host "::error::Failed to sync: $($failed -join ', '). Dependabot will refuse updates while any referenced label is missing."
    exit 1
}

Write-Host "All $($names.Count) label(s) present."
