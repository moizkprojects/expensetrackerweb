Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerName = 'codex-gui-installer.cmd'
$runtimeRoot = Join-Path $env:TEMP 'codex-win-runtime'
$runtimeInstaller = Join-Path $runtimeRoot $installerName

function Resolve-InstallerPath {
    $directCandidates = @(
        (Join-Path $scriptRoot $installerName),
        (Join-Path (Get-Location).Path $installerName),
        (Join-Path (Split-Path -Parent $scriptRoot) $installerName)
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($directCandidates.Count -gt 0) {
        return (Resolve-Path -LiteralPath $directCandidates[0]).Path
    }

    $searchRoots = @(
        $scriptRoot,
        (Get-Location).Path,
        (Join-Path $env:USERPROFILE 'Downloads'),
        $env:TEMP
    )

    foreach ($root in $searchRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
            continue
        }

        $found = Get-ChildItem -LiteralPath $root -Recurse -File -Filter $installerName -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Resolve-InstallerFromZip {
    $zipRoots = @(
        $scriptRoot,
        (Get-Location).Path,
        (Join-Path $env:USERPROFILE 'Downloads')
    )

    $zipCandidates = @()
    foreach ($root in $zipRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
            continue
        }

        $zipCandidates += Get-ChildItem -LiteralPath $root -File -Filter '*.zip' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'codex-win*.zip' -or $_.Name -eq 'main.zip' }
    }

    $zipCandidates = $zipCandidates | Sort-Object LastWriteTime -Descending

    foreach ($zip in $zipCandidates) {
        $extractRoot = Join-Path $env:TEMP ('codex-win-extract-' + [IO.Path]::GetFileNameWithoutExtension($zip.Name))
        try {
            Expand-Archive -LiteralPath $zip.FullName -DestinationPath $extractRoot -Force
        } catch {
            continue
        }

        $found = Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Filter $installerName -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Stage-InstallerToTemp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceInstaller
    )

    New-Item -Path $runtimeRoot -ItemType Directory -Force | Out-Null

    $resolvedSource = (Resolve-Path -LiteralPath $SourceInstaller).Path
    if ($resolvedSource -ne $runtimeInstaller) {
        Copy-Item -LiteralPath $resolvedSource -Destination $runtimeInstaller -Force
    }

    return $runtimeInstaller
}

$installerSource = Resolve-InstallerPath
if (-not $installerSource) {
    $installerSource = Resolve-InstallerFromZip
}

if (-not $installerSource) {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not find $installerName.`n`nExtract codex-win ZIP first, then run codex-gui-frontend.cmd.",
        'Codex GUI Frontend',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

$installer = Stage-InstallerToTemp -SourceInstaller $installerSource
$installerRoot = Split-Path -Parent $installer

function Start-InstallerAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    $command = 'call "' + $installer + '" --close-on-elevate --action "' + $Action + '"'
    $argumentList = @('/k', $command)
    Start-Process -FilePath 'cmd.exe' -ArgumentList $argumentList -WorkingDirectory $installerRoot | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Codex GUI Frontend'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(520, 320)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Codex GUI Installer Frontend'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($title)

$desc = New-Object System.Windows.Forms.Label
$desc.Text = 'Choose an action. Each action opens in a separate console for progress and prompts.'
$desc.AutoSize = $true
$desc.Location = New-Object System.Drawing.Point(20, 58)
$form.Controls.Add($desc)

$buttonFont = New-Object System.Drawing.Font('Segoe UI', 10)

$installBtn = New-Object System.Windows.Forms.Button
$installBtn.Text = 'Install'
$installBtn.Font = $buttonFont
$installBtn.Size = New-Object System.Drawing.Size(220, 44)
$installBtn.Location = New-Object System.Drawing.Point(20, 95)
$installBtn.Add_Click({ Start-InstallerAction -Action 'install' -Title 'Codex Installer - Install' })
$form.Controls.Add($installBtn)

$reinstallBtn = New-Object System.Windows.Forms.Button
$reinstallBtn.Text = 'Reinstall'
$reinstallBtn.Font = $buttonFont
$reinstallBtn.Size = New-Object System.Drawing.Size(220, 44)
$reinstallBtn.Location = New-Object System.Drawing.Point(260, 95)
$reinstallBtn.Add_Click({ Start-InstallerAction -Action 'reinstall' -Title 'Codex Installer - Reinstall' })
$form.Controls.Add($reinstallBtn)

$uninstallBtn = New-Object System.Windows.Forms.Button
$uninstallBtn.Text = 'Uninstall'
$uninstallBtn.Font = $buttonFont
$uninstallBtn.Size = New-Object System.Drawing.Size(220, 44)
$uninstallBtn.Location = New-Object System.Drawing.Point(20, 155)
$uninstallBtn.Add_Click({ Start-InstallerAction -Action 'uninstall' -Title 'Codex Installer - Uninstall' })
$form.Controls.Add($uninstallBtn)

$updateKeyBtn = New-Object System.Windows.Forms.Button
$updateKeyBtn.Text = 'Update API Key'
$updateKeyBtn.Font = $buttonFont
$updateKeyBtn.Size = New-Object System.Drawing.Size(220, 44)
$updateKeyBtn.Location = New-Object System.Drawing.Point(260, 155)
$updateKeyBtn.Add_Click({ Start-InstallerAction -Action 'update-api-key' -Title 'Codex Installer - Update API Key' })
$form.Controls.Add($updateKeyBtn)

$note = New-Object System.Windows.Forms.Label
$note.Text = 'Note: Actions may trigger one UAC prompt and can request API key input in the console.'
$note.AutoSize = $true
$note.Location = New-Object System.Drawing.Point(20, 225)
$form.Controls.Add($note)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = 'Close'
$closeBtn.Font = $buttonFont
$closeBtn.Size = New-Object System.Drawing.Size(100, 34)
$closeBtn.Location = New-Object System.Drawing.Point(380, 248)
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

[void]$form.ShowDialog()
