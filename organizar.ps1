$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
Set-Location -LiteralPath $root

$dirs = @('doc', 'dataintegration', 'data\input', 'data\output', 'data\output\ftp', 'src')
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $dir) | Out-Null
}

$pdf = Join-Path $root 'Relatorio\relatorio.pdf'
if (Test-Path -LiteralPath $pdf) {
    Move-Item -LiteralPath $pdf -Destination (Join-Path $root 'doc\33222_doc.pdf') -Force
}

$rel = Join-Path $root 'Relatorio'
$docRel = Join-Path $root 'doc\relatorio'
if (Test-Path -LiteralPath $rel) {
    if (-not (Test-Path -LiteralPath $docRel)) {
        Move-Item -LiteralPath $rel -Destination $docRel
    }
    else {
        Get-ChildItem -LiteralPath $rel -Force | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination $docRel -Force
        }
        Remove-Item -LiteralPath $rel -Force
    }
}

if (Test-Path -LiteralPath $docRel) {
    Get-ChildItem -LiteralPath $docRel -File | Where-Object {
        $_.Extension -in @('.aux', '.toc', '.lof', '.lot', '.lol', '.out', '.log')
    } | Remove-Item -Force
}

$inputDir = Join-Path $root 'data\input'
$oldInput = Join-Path $root 'Dados_Entrada'
if (Test-Path -LiteralPath $oldInput) {
    Get-ChildItem -LiteralPath $oldInput -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $inputDir -Force
    }
}

$outputDir = Join-Path $root 'data\output'
$oldOutput = Join-Path $root 'Dados_Saida'
if (Test-Path -LiteralPath $oldOutput) {
    Get-ChildItem -LiteralPath $oldOutput -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $outputDir -Force
    }
}

$oldFtp = Join-Path $root 'FTP_remoto'
$ftpDir = Join-Path $root 'data\output\ftp'
if (Test-Path -LiteralPath $oldFtp) {
    New-Item -ItemType Directory -Force -Path $ftpDir | Out-Null
    Get-ChildItem -LiteralPath $oldFtp -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $ftpDir -Force
    }
}

$integrationDir = Join-Path $root 'dataintegration'
foreach ($oldDirName in @('Transformacoes', 'Jobs')) {
    $oldDir = Join-Path $root $oldDirName
    if (Test-Path -LiteralPath $oldDir) {
        Get-ChildItem -LiteralPath $oldDir -Force | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination $integrationDir -Force
        }
    }
}

$oldNodeRed = Join-Path $root 'NodeRED'
$srcDir = Join-Path $root 'src'
if (Test-Path -LiteralPath $oldNodeRed) {
    Get-ChildItem -LiteralPath $oldNodeRed -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $srcDir -Force
    }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

Get-ChildItem -LiteralPath $integrationDir -File | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $text = $text.Replace('\Dados_Entrada\', '\data\input\')
    $text = $text.Replace('\Dados_Entrada', '\data\input')
    $text = $text.Replace('\Dados_Saida\', '\data\output\')
    $text = $text.Replace('\Dados_Saida', '\data\output')
    $text = $text.Replace('\FTP_remoto\', '\data\output\ftp\')
    $text = $text.Replace('\FTP_remoto', '\data\output\ftp')
    $text = $text.Replace('\Transformacoes\', '\dataintegration\')
    $text = $text.Replace('\Jobs\', '\dataintegration\')
    [System.IO.File]::WriteAllText($_.FullName, $text, $utf8)
}

$flow = Join-Path $srcDir 'flows.json'
if (Test-Path -LiteralPath $flow) {
    $text = Get-Content -LiteralPath $flow -Raw -Encoding UTF8
    $text = $text.Replace('\\Dados_Saida\\', '\\data\\output\\')
    $text = $text.Replace('\\Dados_Saida', '\\data\\output')
    [System.IO.File]::WriteAllText($flow, $text, $utf8)
}

$texput = Join-Path $root 'texput.log'
if (Test-Path -LiteralPath $texput) {
    Remove-Item -LiteralPath $texput -Force
}

function Remove-EmptyDir($path) {
    if (Test-Path -LiteralPath $path) {
        $count = @(Get-ChildItem -LiteralPath $path -Force).Count
        if ($count -eq 0) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

foreach ($oldDirName in @('Dados_Entrada', 'Dados_Saida', 'FTP_remoto', 'Transformacoes', 'Jobs', 'NodeRED')) {
    Remove-EmptyDir (Join-Path $root $oldDirName)
}

Write-Host 'Estrutura organizada. Verifica:'
Get-ChildItem -LiteralPath $root | Select-Object Name
Write-Host 'Podes apagar organizar.ps1 depois de confirmar a estrutura.'
