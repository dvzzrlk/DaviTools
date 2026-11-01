param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Prepare', 'Cleanup')]
  [string]$Mode,

  [Parameter(Mandatory = $true)]
  [string]$AppDataPath,

  [Parameter(Mandatory = $true)]
  [string]$TargetsFile
)

$ErrorActionPreference = 'Stop'
$appDataRoot = [System.IO.Path]::GetFullPath($AppDataPath).TrimEnd('\')
$settingsRoot = Join-Path $appDataRoot 'DaviTools'

if ($Mode -eq 'Prepare') {
  $targets = [System.Collections.Generic.List[string]]::new()

  $settingsPath = Join-Path $settingsRoot 'settings.json'
  if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    foreach ($key in @('backupsDir', 'logsDir')) {
      $configuredPath = $settings.storage.$key
      if ([string]::IsNullOrWhiteSpace($configuredPath)) {
        continue
      }

      if (-not [System.IO.Path]::IsPathRooted($configuredPath)) {
        throw "O caminho configurado para $key não é absoluto."
      }

      $targets.Add([System.IO.Path]::GetFullPath($configuredPath))
    }
  }

  $targets | Sort-Object -Unique | Set-Content -LiteralPath $TargetsFile -Encoding UTF8
  exit 0
}

if (-not (Test-Path -LiteralPath $TargetsFile -PathType Leaf)) {
  throw 'A lista temporária de pastas para limpeza não foi encontrada.'
}

$windowsRoot = [System.IO.Path]::GetFullPath($env:SystemRoot).TrimEnd('\')
$protectedRoots = @(
  $appDataRoot,
  [System.IO.Path]::GetFullPath([System.Environment]::GetFolderPath('UserProfile')).TrimEnd('\'),
  [System.Environment]::GetFolderPath('DesktopDirectory'),
  [System.Environment]::GetFolderPath('MyDocuments'),
  [System.Environment]::GetFolderPath('MyPictures'),
  [System.Environment]::GetFolderPath('MyMusic'),
  [System.Environment]::GetFolderPath('MyVideos'),
  (Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'Downloads'),
  [System.IO.Path]::GetPathRoot($appDataRoot).TrimEnd('\'),
  $windowsRoot,
  [System.IO.Path]::GetFullPath($env:ProgramFiles).TrimEnd('\'),
  [System.IO.Path]::GetFullPath(${env:ProgramFiles(x86)}).TrimEnd('\'),
  [System.IO.Path]::GetFullPath($env:ProgramData).TrimEnd('\')
) | Where-Object { $_ }
$protectedSystemRoots = @(
  $windowsRoot,
  [System.IO.Path]::GetFullPath($env:ProgramFiles).TrimEnd('\'),
  [System.IO.Path]::GetFullPath(${env:ProgramFiles(x86)}).TrimEnd('\'),
  [System.IO.Path]::GetFullPath($env:ProgramData).TrimEnd('\')
) | Where-Object { $_ }

$targetsToRemove = [System.Collections.Generic.List[string]]::new()
foreach ($line in Get-Content -LiteralPath $TargetsFile) {
  if ([string]::IsNullOrWhiteSpace($line)) {
    continue
  }

  if ($line.StartsWith('\\')) {
    throw 'Network backup folders are preserved and must be removed manually.'
  }

  $target = [System.IO.Path]::GetFullPath($line).TrimEnd('\')
  $isProtected = $false

  foreach ($root in $protectedRoots) {
    if (
      [string]::Equals($target, $root, [System.StringComparison]::OrdinalIgnoreCase) -or
      $root.StartsWith($target + '\', [System.StringComparison]::OrdinalIgnoreCase)
    ) {
      $isProtected = $true
      break
    }
  }

  if (-not $isProtected) {
    foreach ($root in $protectedSystemRoots) {
      if ($target.StartsWith($root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $isProtected = $true
        break
      }
    }
  }

  if ($isProtected) {
    throw "The configured cleanup path is broad or protected and was preserved: $target"
  }

  if (-not (Test-Path -LiteralPath $target)) {
    continue
  }

  $item = Get-Item -LiteralPath $target -Force
  if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    throw "The configured cleanup path is a link and was preserved: $target"
  }

  $targetsToRemove.Add($target)
}

foreach ($target in $targetsToRemove) {
  $item = Get-Item -LiteralPath $target -Force
  if ($item.PSIsContainer) {
    $links = Get-ChildItem -LiteralPath $target -Force -Recurse |
      Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }
    if ($links) {
      throw "The configured cleanup folder contains links and was preserved: $target"
    }
  }

  Remove-Item -LiteralPath $target -Recurse -Force
}
