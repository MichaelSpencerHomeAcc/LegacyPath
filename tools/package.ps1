# Builds dist\LegacyPath-<version>.zip containing the LegacyPath addon folder.
# Run from the repo root:  powershell -File tools\package.ps1
# Writes the ZIP with .NET directly (not tar.exe, which may be Git's and write a tar instead),
# with forward-slash entry names as addon managers expect.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$root = (Get-Location).Path
$version = (Select-String -Path LegacyPath\LegacyPath.toc -Pattern '^## Version: (.+)$').Matches[0].Groups[1].Value.Trim()
New-Item -ItemType Directory -Force dist | Out-Null
$zip = Join-Path $root "dist\LegacyPath-$version.zip"
if (Test-Path $zip) { Remove-Item $zip }

$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
	Get-ChildItem LegacyPath -Recurse -File | Sort-Object FullName | ForEach-Object {
		$name = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
		[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $name, 'Optimal')
	}
} finally {
	$archive.Dispose()
}
Write-Output "dist\LegacyPath-$version.zip"
