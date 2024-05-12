Function Info($msg) {
  Write-Host -ForegroundColor DarkGreen "`nINFO: $msg`n"
}

Function Error($msg) {
  Write-Host `n`n
  Write-Error $msg
  exit 1
}

Function CheckReturnCodeOfPreviousCommand($msg) {
  if(-Not $?) {
    Error "${msg}. Error code: $LastExitCode"
  }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = $PSScriptRoot
$buildDir = "$root/build"

Info "Find Visual Studio installation path"
$vswhereCommand = Get-Command -Name "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installationPath = & $vswhereCommand -prerelease -latest -property installationPath

Info "Open Visual Studio 2022 Developer PowerShell"
& "$installationPath\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64

Info "Remove '$buildDir' folder if it exists"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item $buildDir -Force -ItemType "directory" > $null

Info "Download Zlib"
Invoke-WebRequest -Uri https://github.com/madler/zlib/archive/refs/tags/v1.3.1.zip -OutFile $buildDir/zlib.zip

Info "Extract Zlib"
[System.IO.Compression.ZipFile]::ExtractToDirectory("$buildDir/zlib.zip", "$buildDir")
Rename-Item -Path $buildDir/zlib-1.3.1 $buildDir/zlib

Info "Compile Zlib - generate cache"
cmake `
  -S $buildDir/zlib `
  -B $buildDir/zlib-out `
  -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
  -DZLIB_BUILD_EXAMPLES=OFF
CheckReturnCodeOfPreviousCommand "cmake cache failed"

Info "Compile Zlib - build"
cmake --build $buildDir/zlib-out
CheckReturnCodeOfPreviousCommand "cmake build failed"

Info "Download Minisat source code"
Invoke-WebRequest -Uri https://github.com/niklasso/minisat/archive/37dc6c67e2af26379d88ce349eb9c4c6160e8543.zip -OutFile $buildDir/minisat.zip

Info "Extract the source code"
[System.IO.Compression.ZipFile]::ExtractToDirectory("$buildDir/minisat.zip", "$buildDir")
Rename-Item -Path $buildDir/minisat-37dc6c67e2af26379d88ce349eb9c4c6160e8543 -NewName $buildDir/minisat

Info "Copy patch files to the Minisat sources"
Copy-Item -Path $root/patch_files/* -Destination $buildDir/minisat -Recurse -Force

Info "Apply necessary source code fixes to make Minisat compile"
(Get-Content $buildDir/minisat/minisat/utils/System.cc).Replace("double Minisat::memUsedPeak() { return 0; }", "double Minisat::memUsedPeak(bool strictlyPeak) { return 0; }") | Set-Content $buildDir/minisat/minisat/utils/System.cc
(Get-Content $buildDir/minisat/minisat/core/Solver.cc).Replace('"PRIu64"', "llu") | Set-Content $buildDir/minisat/minisat/core/Solver.cc

Info "Cmake generate cache"
cmake `
  -S $buildDir/minisat `
  -B $buildDir/out `
  -G Ninja `
  -DCMAKE_BUILD_TYPE=Release
CheckReturnCodeOfPreviousCommand "cmake cache failed"

Info "Cmake build"
cmake --build $buildDir/out
CheckReturnCodeOfPreviousCommand "cmake build failed"

Info "Copy the executable to the publish directory and archive it"
New-Item $buildDir/publish -Force -ItemType "directory" > $null
Copy-Item -Path $buildDir/out/minisat*.exe -Destination $buildDir/publish
Compress-Archive -Path "$buildDir/publish/*.exe" -DestinationPath $buildDir/publish/minisat.zip
