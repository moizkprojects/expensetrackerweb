param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "ERROR: Config file not found: $ConfigPath"
    exit 1
}

$content = Get-Content -Raw -Path $ConfigPath
$sections = [regex]::Matches($content, '(?ms)^\[profiles\.([^\]\r\n]+)\]\s*(.*?)(?=^\[|\z)')
$profiles = @()

foreach ($s in $sections) {
    $name = $s.Groups[1].Value.Trim()
    $match = [regex]::Match($s.Groups[2].Value, '(?m)^\s*model\s*=\s*"([^"]+)"')
    if ($match.Success) {
        $profiles += [pscustomobject]@{
            Name = $name
            Model = $match.Groups[1].Value
        }
    }
}

if ($profiles.Count -eq 0) {
    Write-Host "ERROR: No profile models found in: $ConfigPath"
    exit 1
}

$currentProfile = ([regex]::Match($content, '(?m)^\s*profile\s*=\s*"([^"]+)"')).Groups[1].Value
$currentModel = ([regex]::Match($content, '(?m)^\s*model\s*=\s*"([^"]+)"')).Groups[1].Value

Write-Host '==== Switch Default Model ===='
Write-Host "Config file: $ConfigPath"
Write-Host "Discovered profiles: $($profiles.Count)"
if ($currentProfile -or $currentModel) {
    Write-Host ("Current default: profile='{0}', model='{1}'" -f $currentProfile, $currentModel)
}

for ($i = 0; $i -lt $profiles.Count; $i++) {
    Write-Host ("[{0}] {1} : {2}" -f ($i + 1), $profiles[$i].Name, $profiles[$i].Model)
}

$choice = Read-Host 'Select a profile number (or Q to cancel)'
if ($choice -match '^(?i)q$') {
    Write-Host 'Model switch cancelled.'
    exit 0
}

[int]$index = 0
if (-not [int]::TryParse($choice, [ref]$index)) {
    Write-Host 'ERROR: Invalid selection.'
    exit 1
}

if ($index -lt 1 -or $index -gt $profiles.Count) {
    Write-Host 'ERROR: Selection out of range.'
    exit 1
}

$selected = $profiles[$index - 1]
$newProfile = $selected.Name
$newModel = $selected.Model

$firstSection = [regex]::Match($content, '(?m)^\[')
if ($firstSection.Success) {
    $topLevel = $content.Substring(0, $firstSection.Index)
    $rest = $content.Substring($firstSection.Index)
} else {
    $topLevel = $content
    $rest = ''
}

if ([regex]::IsMatch($topLevel, '(?m)^\s*profile\s*=\s*".*?"\s*$')) {
    $topLevel = [regex]::Replace($topLevel, '(?m)^\s*profile\s*=\s*".*?"\s*$', ('profile = "' + $newProfile + '"'))
} else {
    $topLevel = 'profile = "' + $newProfile + '"' + [Environment]::NewLine + $topLevel
}

if ([regex]::IsMatch($topLevel, '(?m)^\s*model\s*=\s*".*?"\s*$')) {
    $topLevel = [regex]::Replace($topLevel, '(?m)^\s*model\s*=\s*".*?"\s*$', ('model = "' + $newModel + '"'))
} else {
    $topLevel = 'model = "' + $newModel + '"' + [Environment]::NewLine + $topLevel
}

if ($rest -and $topLevel -notmatch '(\r?\n)$') {
    $topLevel += [Environment]::NewLine
}

$content = $topLevel + $rest

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ConfigPath, $content, $enc)

Write-Host ("Updated defaults to profile='{0}', model='{1}'." -f $newProfile, $newModel)
exit 0
