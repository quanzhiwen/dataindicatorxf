# DataIndicatorXF 一键打包脚本（Windows -> WSL 内的 theos）
# 用法：
#   .\wsl-build.ps1                    # 只打 rootless 包（Dopamine/strix/palera1n rootless）
#   .\wsl-build.ps1 -Scheme roothide   # 只打 roothide 包
#   .\wsl-build.ps1 -Scheme all        # rootless + roothide 都打
#   .\wsl-build.ps1 -Scheme rootful    # 老式 rootful 越狱
#   .\wsl-build.ps1 -Distro Ubuntu -Install   # 指定 WSL 发行版并 pushinstall 到设备
#
# 前置条件（WSL 内一次性）：
#   sudo apt install make perl git xz-utils zip unzip libplist-dev libsqlite3-dev llvm clang
#   git clone --recursive https://github.com/theos/theos.git ~/theos
#   export THEOS=~/theos   （写入 ~/.bashrc；roothide 方案需要较新的 theos，已内置 roothide scheme 支持）

param(
    [string]$Scheme = "rootless",
    [string]$Distro = "",
    [switch]$Install
)

$ErrorActionPreference = "Stop"
$projectDir = $PSScriptRoot

# Windows 路径 -> WSL 路径 (e:\gitdata\sjbs -> /mnt/e/gitdata/sjbs)
$mntPath = ($projectDir -replace '^([A-Za-z]):', '/mnt/$1') -replace '\\', '/'
$mntPath = $mntPath.ToLower()

$wslCmd = @(if ($Distro) { @("-d", $Distro) } else { @() })

switch ($Scheme) {
    "all"     { $schemes = @("rootless", "roothide") }
    "rootful" { $schemes = @("") }                # 空方案 = rootful
    default   { $schemes = @($Scheme) }
}

New-Item -ItemType Directory -Force -Path "$projectDir\out" | Out-Null

foreach ($s in $schemes) {
    $label = if ($s -eq "") { "rootful" } else { $s }
    Write-Host "==== 构建 $label 包 ====" -ForegroundColor Cyan

    $schemeArg = if ($s -eq "") { "THEOS_PACKAGE_SCHEME=" } else { "THEOS_PACKAGE_SCHEME=$s" }
    $target = if ($Install) { "package install" } else { "package" }

    $script = "source ~/.bashrc; export THEOS=`${THEOS:-`$HOME/theos}; " +
              "cd '$mntPath' && make clean; make $target $schemeArg"

    wsl $wslCmd bash -lc $script
    if ($LASTEXITCODE -ne 0) { throw "$label 构建失败" }

    # 收集产物到 out\<label>\
    $dest = "$projectDir\out\$label"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem "$projectDir\packages\*.deb" | ForEach-Object {
        Copy-Item $_.FullName -Destination $dest -Force
        Write-Host "产物: out\$label\$($_.Name)" -ForegroundColor Green
    }
    Remove-Item "$projectDir\packages\*.deb" -Force -ErrorAction SilentlyContinue
}

Write-Host "全部完成" -ForegroundColor Cyan
