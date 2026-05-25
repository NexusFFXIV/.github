<#
.SYNOPSIS
Appends a "📦 Internal Dependency Changes" block to a GitHub Release body.

.DESCRIPTION
Diffs csproj PackageReferences and packages.lock.json resolved versions between
the previous and current tag in the current repo, identifies internal (NexusFFXIV
org) package bumps, fetches the PR list from each sub-repo via `gh api compare`,
and rewrites the current release body with the expanded changelog appended.
#>

param(
    [Parameter(Mandatory)][string]$ReleaseTag,
    [string]$LockfileGlobs = '**/packages.lock.json',
    [string]$CsprojGlobs   = '**/*.csproj',
    [string]$PackagePrefix = 'NexusKit.',
    [string]$PrefixMap     = '{"NexusKit.Modules.":"NexusFFXIV/NexusKit.Modules","NexusKit.":"NexusFFXIV/NexusKit"}',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Script:BlockHeader     = '## 📦 Internal Dependency Changes'
$Script:BlockSeparator  = "`n`n---`n`n"

function Write-Notice([string]$msg) { Write-Host "::notice::$msg" }
function Write-Warn  ([string]$msg) { Write-Host "::warning::$msg" }

# ---------------------------------------------------------------------------
# 1. Determine the predecessor tag.
# ---------------------------------------------------------------------------
function Get-PreviousTag([string]$currentTag, [string]$repo) {
    $isPrerelease = $currentTag.Contains('-')
    $json = gh release list --repo $repo --limit 50 --json tagName,isDraft,isPrerelease,createdAt 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { return $null }
    $releases = $json | ConvertFrom-Json | Sort-Object -Property createdAt -Descending
    foreach ($r in $releases) {
        if ($r.tagName -eq $currentTag) { continue }
        if ($r.isDraft) { continue }
        if (-not $isPrerelease -and $r.isPrerelease) { continue }
        return $r.tagName
    }
    return $null
}

# ---------------------------------------------------------------------------
# 2. Parse csproj PackageReferences whose Include starts with $PackagePrefix.
# Returns hashtable: Id -> rangeString (e.g. '[0.1.0,)')
# ---------------------------------------------------------------------------
function Get-CsprojRefs([string]$xmlContent, [string]$prefix) {
    $refs = @{}
    if ([string]::IsNullOrWhiteSpace($xmlContent)) { return $refs }
    $pattern = '<PackageReference\s+[^>]*Include="(?<id>' + [Regex]::Escape($prefix) + '[^"]+)"[^>]*Version="(?<ver>[^"]+)"'
    foreach ($m in [Regex]::Matches($xmlContent, $pattern)) {
        $refs[$m.Groups['id'].Value] = $m.Groups['ver'].Value
    }
    return $refs
}

# Extract the lower-bound version from a NuGet version string.
# Handles '[0.1.0,)', '[0.1.0,0.2.0)', '0.1.0', '[0.1.0]'.
function Get-RangeLowerBound([string]$range) {
    if ([string]::IsNullOrWhiteSpace($range)) { return $null }
    $r = $range.Trim()
    $r = $r -replace '^\[|^\(', '' -replace '\]$|\)$', ''
    return ($r -split ',')[0].Trim()
}

# ---------------------------------------------------------------------------
# 3. Parse packages.lock.json dependencies (all frameworks, all types).
# Returns hashtable: Id -> resolvedVersion
# ---------------------------------------------------------------------------
function Get-LockfileResolutions([string]$jsonContent, [string]$prefix) {
    $map = @{}
    if ([string]::IsNullOrWhiteSpace($jsonContent)) { return $map }
    try { $lock = $jsonContent | ConvertFrom-Json } catch { return $map }
    if (-not $lock.dependencies) { return $map }
    foreach ($framework in $lock.dependencies.PSObject.Properties) {
        $deps = $framework.Value
        if (-not $deps) { continue }
        foreach ($pkg in $deps.PSObject.Properties) {
            if (-not $pkg.Name.StartsWith($prefix)) { continue }
            $resolved = $pkg.Value.resolved
            if (-not $resolved) { continue }
            $map[$pkg.Name] = [string]$resolved
        }
    }
    return $map
}

# ---------------------------------------------------------------------------
# 4. Map a package ID to its source repo using the longest-prefix-wins JSON map.
# ---------------------------------------------------------------------------
function Resolve-SourceRepo([string]$id, $prefixMap) {
    $best = $null
    $bestLen = -1
    foreach ($p in $prefixMap.PSObject.Properties) {
        if ($id.StartsWith($p.Name) -and $p.Name.Length -gt $bestLen) {
            $best = $p.Value
            $bestLen = $p.Name.Length
        }
    }
    return $best
}

# ---------------------------------------------------------------------------
# 5. Read file contents at a specific git ref. Empty string on miss.
# ---------------------------------------------------------------------------
function Get-FileAtRef([string]$ref, [string]$path) {
    $content = git show "${ref}:${path}" 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return ($content -join "`n")
}

# ---------------------------------------------------------------------------
# 6. Fetch the PR-titles for the version range from a source repo.
# Returns: @{ Items=@(@{Title,PrNumber,Url}); CompareUrl=...; Found=$true|$false }
# ---------------------------------------------------------------------------
function Get-SubRepoPrs([string]$sourceRepo, [string]$fromVer, [string]$toVer) {
    $fromTag = "v$fromVer"
    $toTag   = "v$toVer"
    $compareUrl = "https://github.com/$sourceRepo/compare/$fromTag...$toTag"
    $json = gh api "repos/$sourceRepo/compare/$fromTag...$toTag" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) {
        return [PSCustomObject]@{ Items = @(); CompareUrl = $compareUrl; Found = $false }
    }
    $data = $json | ConvertFrom-Json
    $items = New-Object System.Collections.Generic.List[object]
    $seenPrs = New-Object System.Collections.Generic.HashSet[string]
    foreach ($c in @($data.commits)) {
        $msg = ($c.commit.message -split "`n", 2)[0]
        $prMatch = [Regex]::Match($msg, '\(#(?<n>\d+)\)\s*$')
        $prNum   = $null
        if ($prMatch.Success) {
            $prNum = $prMatch.Groups['n'].Value
            if (-not $seenPrs.Add($prNum)) { continue }
        }
        $items.Add([PSCustomObject]@{
            Title    = $msg
            PrNumber = $prNum
            Sha      = $c.sha
        }) | Out-Null
    }
    return [PSCustomObject]@{
        Items      = $items.ToArray()
        CompareUrl = $compareUrl
        Found      = $true
    }
}

# ---------------------------------------------------------------------------
# 7. Render the markdown block.
# ---------------------------------------------------------------------------
function Format-Block($bumps) {
    if ($bumps.Count -eq 0) { return $null }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine($Script:BlockHeader)
    [void]$sb.AppendLine()
    foreach ($b in ($bumps | Sort-Object Id)) {
        $title = "### $($b.Id): $($b.EffectiveOld) → $($b.EffectiveNew)"
        if ($b.Reason -eq 'range-raised' -or $b.Reason -eq 'range-only') {
            $title += "  _(range raised: $($b.OldRange) → $($b.NewRange))_"
        } elseif ($b.Reason -eq 'added') {
            $title = "### $($b.Id): (new) → $($b.EffectiveNew)"
        }
        [void]$sb.AppendLine($title)

        if (-not $b.Prs.Found) {
            [void]$sb.AppendLine('- _Sub-Repo-Tag nicht gefunden — siehe Compare-Link._')
        } elseif ($b.Prs.Items.Count -eq 0) {
            [void]$sb.AppendLine('- _Keine PRs zwischen den Tags._')
        } else {
            foreach ($pr in $b.Prs.Items) {
                if ($pr.PrNumber) {
                    [void]$sb.AppendLine("- $($pr.Title)")
                } else {
                    $short = $pr.Sha.Substring(0, 7)
                    [void]$sb.AppendLine("- $($pr.Title) ($short)")
                }
            }
        }
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("_Full diff: [$($b.SourceRepo)/compare/v$($b.EffectiveOld)...v$($b.EffectiveNew)]($($b.Prs.CompareUrl))_")
        [void]$sb.AppendLine()
    }
    return $sb.ToString().TrimEnd()
}

# ---------------------------------------------------------------------------
# 8. Splice the rendered block into the existing release body (idempotent).
# ---------------------------------------------------------------------------
function Merge-IntoBody([string]$existingBody, [string]$newBlock) {
    if (-not $existingBody) { $existingBody = '' }
    # Strip a previous occurrence of our block (separator + header onwards).
    $idx = $existingBody.IndexOf($Script:BlockHeader)
    if ($idx -ge 0) {
        # Also strip the separator before, if present.
        $sepIdx = $existingBody.LastIndexOf("`n---`n", $idx)
        if ($sepIdx -ge 0 -and ($idx - $sepIdx) -lt 10) {
            $existingBody = $existingBody.Substring(0, $sepIdx).TrimEnd()
        } else {
            $existingBody = $existingBody.Substring(0, $idx).TrimEnd()
        }
    }
    return $existingBody + $Script:BlockSeparator + $newBlock
}

# ===========================================================================
# Main
# ===========================================================================

$repo = $env:GITHUB_REPOSITORY
if (-not $repo) { throw 'GITHUB_REPOSITORY env not set' }

Write-Host "Expanding internal dependency changelog for $repo @ $ReleaseTag"

$prevTag = Get-PreviousTag -currentTag $ReleaseTag -repo $repo
if (-not $prevTag) {
    Write-Notice 'first release, nothing to expand'
    exit 0
}
Write-Host "Previous tag: $prevTag"

$prefixMapObj = $PrefixMap | ConvertFrom-Json

# Collect csproj + lockfile paths from the working tree (= new tag).
$csprojFiles   = Get-ChildItem -Recurse -File -Filter '*.csproj'           -ErrorAction SilentlyContinue
$lockfileFiles = Get-ChildItem -Recurse -File -Filter 'packages.lock.json' -ErrorAction SilentlyContinue

# Also include paths that existed at the previous tag but were removed since.
$prevCsprojs   = (git ls-tree -r --name-only $prevTag 2>$null) | Where-Object { $_ -match '\.csproj$' }
$prevLockfiles = (git ls-tree -r --name-only $prevTag 2>$null) | Where-Object { $_ -match 'packages\.lock\.json$' }

# Accumulators across the whole repo.
$oldCsprojRefs  = @{}; $newCsprojRefs  = @{}
$oldLockRes     = @{}; $newLockRes     = @{}

function Add-CsprojRange([hashtable]$bag, [hashtable]$found) {
    foreach ($k in $found.Keys) {
        if (-not $bag.ContainsKey($k)) { $bag[$k] = $found[$k] }
        # Multiple csprojs declaring the same package: first-wins is fine — we use the value as range signal only.
    }
}
function Add-LockResolution([hashtable]$bag, [hashtable]$found) {
    foreach ($k in $found.Keys) {
        if (-not $bag.ContainsKey($k)) { $bag[$k] = $found[$k] }
    }
}

# New (working tree) - csproj
foreach ($f in $csprojFiles) {
    $content = Get-Content -Raw -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    Add-CsprojRange $newCsprojRefs (Get-CsprojRefs $content $PackagePrefix)
}
# New (working tree) - lockfile
foreach ($f in $lockfileFiles) {
    $content = Get-Content -Raw -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    Add-LockResolution $newLockRes (Get-LockfileResolutions $content $PackagePrefix)
}
# Old (previous tag) - csproj
foreach ($p in $prevCsprojs) {
    $content = Get-FileAtRef $prevTag $p
    Add-CsprojRange $oldCsprojRefs (Get-CsprojRefs $content $PackagePrefix)
}
# Old (previous tag) - lockfile
foreach ($p in $prevLockfiles) {
    $content = Get-FileAtRef $prevTag $p
    Add-LockResolution $oldLockRes (Get-LockfileResolutions $content $PackagePrefix)
}

# Union of all package IDs seen anywhere.
$allIds = New-Object System.Collections.Generic.HashSet[string]
@($oldCsprojRefs.Keys; $newCsprojRefs.Keys; $oldLockRes.Keys; $newLockRes.Keys) |
    ForEach-Object { [void]$allIds.Add($_) }

$bumps = New-Object System.Collections.Generic.List[object]
foreach ($id in $allIds) {
    $oldRange = $oldCsprojRefs[$id]
    $newRange = $newCsprojRefs[$id]
    $oldRes   = $oldLockRes[$id]
    $newRes   = $newLockRes[$id]

    $sourceRepo = Resolve-SourceRepo $id $prefixMapObj
    if (-not $sourceRepo) { continue }

    $hasRangeDelta = ($oldRange -or $newRange) -and ($oldRange -ne $newRange)
    $hasResDelta   = ($oldRes -or $newRes)     -and ($oldRes   -ne $newRes)
    if (-not $hasRangeDelta -and -not $hasResDelta) { continue }

    # Reason marker.
    $reason = if ($null -eq $oldRange -and $null -eq $oldRes) { 'added' }
              elseif ($null -eq $newRange -and $null -eq $newRes) { 'removed' }
              elseif ($hasRangeDelta -and $hasResDelta) { 'range-raised' }
              elseif ($hasRangeDelta) { 'range-only' }
              else { 'floating-resolve' }

    if ($reason -eq 'removed') { continue }   # not interesting for the user

    # Effective span: tolerant union of lockfile and csproj-range lower bounds.
    $oldCandidates = @()
    if ($oldRes)   { $oldCandidates += $oldRes }
    if ($oldRange) { $oldCandidates += (Get-RangeLowerBound $oldRange) }
    $newCandidates = @()
    if ($newRes)   { $newCandidates += $newRes }
    if ($newRange) { $newCandidates += (Get-RangeLowerBound $newRange) }

    $effectiveOld = ($oldCandidates | Sort-Object { [version](($_ -split '-')[0]) } | Select-Object -First 1)
    $effectiveNew = ($newCandidates | Sort-Object { [version](($_ -split '-')[0]) } -Descending | Select-Object -First 1)

    if (-not $effectiveOld -or -not $effectiveNew -or $effectiveOld -eq $effectiveNew) {
        # Nothing useful to compare.
        continue
    }

    $prs = Get-SubRepoPrs -sourceRepo $sourceRepo -fromVer $effectiveOld -toVer $effectiveNew

    $bumps.Add([PSCustomObject]@{
        Id           = $id
        OldRange     = $oldRange
        NewRange     = $newRange
        OldResolved  = $oldRes
        NewResolved  = $newRes
        EffectiveOld = $effectiveOld
        EffectiveNew = $effectiveNew
        Reason       = $reason
        SourceRepo   = $sourceRepo
        Prs          = $prs
    }) | Out-Null
}

if ($bumps.Count -eq 0) {
    Write-Notice 'no internal dependency bumps detected, nothing to append'
    exit 0
}

$block = Format-Block $bumps
Write-Host '--- Generated block ---'
Write-Host $block
Write-Host '--- End block ---'

# Fetch existing body, splice, push back.
$existingJson = gh release view $ReleaseTag --repo $repo --json body 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "could not fetch existing release body for $ReleaseTag — aborting"
    exit 1
}
$existingBody = ($existingJson | ConvertFrom-Json).body
$newBody = Merge-IntoBody -existingBody $existingBody -newBlock $block

if ($DryRun) {
    Write-Host '--- DRY RUN: new release body would be ---'
    Write-Host $newBody
    Write-Host '--- end body ---'
    Write-Notice "DryRun: $($bumps.Count) internal dep change(s) would be appended to $ReleaseTag."
    exit 0
}

# Write to a temp file to avoid shell-quoting issues with multi-line bodies.
$tmp = New-TemporaryFile
try {
    Set-Content -LiteralPath $tmp.FullName -Value $newBody -Encoding utf8 -NoNewline
    gh release edit $ReleaseTag --repo $repo --notes-file $tmp.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'gh release edit failed' }
    Write-Host "Release $ReleaseTag updated with $($bumps.Count) internal dep change(s)."
} finally {
    Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue
}
