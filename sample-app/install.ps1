$ErrorActionPreference = "Stop"
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$dest = "C:\inetpub\wwwroot"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$skip = @(
    "aws-windows-deployment-manifest.json",
    "install.ps1",
    "restart.ps1",
    "uninstall.ps1",
    "site"
)

# Copy root-level files and folders (bin, Views, Content, etc.). -File only
# would drop Matchbook publish output on the floor.
Get-ChildItem -LiteralPath $scriptDir | Where-Object { $skip -notcontains $_.Name } | ForEach-Object {
    $target = Join-Path $dest $_.Name
    Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
}

$siteDir = Join-Path $scriptDir "site"
if (Test-Path -LiteralPath $siteDir) {
    Get-ChildItem -LiteralPath $siteDir | ForEach-Object {
        $target = Join-Path $dest $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
    }
}
