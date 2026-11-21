# Builds dist\LegacyPath-<version>.zip containing the LegacyPath addon folder.
# Run from the repo root:  powershell -File tools\package.ps1
$version = (Select-String -Path LegacyPath\LegacyPath.toc -Pattern '^## Version: (.+)$').Matches[0].Groups[1].Value
New-Item -ItemType Directory -Force dist | Out-Null
$zip = "dist\LegacyPath-$version.zip"
if (Test-Path $zip) { Remove-Item $zip }
tar.exe -a -c -f $zip LegacyPath
Write-Output $zip
