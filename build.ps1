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

Info "Create build and publish directory"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue > $null
New-Item $buildDir/publish -Force -ItemType "directory" > $null

Info "Download Minisat source code"
Invoke-WebRequest -Uri https://github.com/niklasso/minisat/archive/37dc6c67e2af26379d88ce349eb9c4c6160e8543.zip -OutFile $buildDir/minisat.zip

Info "Extract the source code"
[System.IO.Compression.ZipFile]::ExtractToDirectory("$buildDir/minisat.zip", "$buildDir")
Rename-Item -Path $buildDir/minisat-37dc6c67e2af26379d88ce349eb9c4c6160e8543 -NewName $buildDir/minisat

Info "Copy 'CMakeLists.txt' and 'vcpkg.json' file to the Minisat sources"
Copy-Item -Path $root/CMakeLists.txt, $root/vcpkg.json -Destination $buildDir/minisat -Recurse -Force

Info "Apply necessary source code fixes to make Minisat compile"
(Get-Content $buildDir/minisat/minisat/utils/System.cc).Replace("double Minisat::memUsedPeak() { return 0; }", "double Minisat::memUsedPeak(bool strictlyPeak) { return 0; }") | Set-Content $buildDir/minisat/minisat/utils/System.cc
(Get-Content $buildDir/minisat/minisat/core/Solver.cc).Replace('"PRIu64"', "llu") | Set-Content $buildDir/minisat/minisat/core/Solver.cc

Info "Cmake generate cache"
cmake `
  -S $buildDir/minisat `
  -B $buildDir/out `
  -G Ninja `
  -D CMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" `
  -D VCPKG_TARGET_TRIPLET=x64-windows-static-release `
  -D CMAKE_BUILD_TYPE=Release
CheckReturnCodeOfPreviousCommand "cmake cache failed"

Info "Cmake build"
cmake --build $buildDir/out
CheckReturnCodeOfPreviousCommand "cmake build failed"

Info "Copy the executable to the publish directory and archive them"
Copy-Item -Path $buildDir/out/minisat*.exe -Destination $buildDir/publish
Compress-Archive -Path "$buildDir/publish/*.exe" -DestinationPath $buildDir/publish/minisat.zip
