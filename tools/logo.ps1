# Draws media\logo-400.png, the CurseForge project logo: a winding path of milestones
# rising to a star. Uses .NET System.Drawing, so it needs Windows PowerShell and nothing else.
# Run from the repo root:  powershell -File tools\logo.ps1
Add-Type -AssemblyName System.Drawing
$S = 400
$bmp = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'

function Color($hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

# Background: night-blue gradient.
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 0, $S), (Color '#1d2a4d'), (Color '#0b1020')
$g.FillRectangle($bg, 0, 0, $S, $S)

# Spectral glow behind the goal.
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(190, 10, 200, 200)
$gb = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$gb.CenterColor = [System.Drawing.Color]::FromArgb(140, 110, 190, 255)
$gb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 110, 190, 255))
$g.FillPath($gb, $glow)

# The path: a dashed S-curve from bottom-left to the star.
$points = [System.Drawing.PointF[]]@(
	(New-Object System.Drawing.PointF 60, 360), (New-Object System.Drawing.PointF 230, 340),
	(New-Object System.Drawing.PointF 120, 220), (New-Object System.Drawing.PointF 250, 190),
	(New-Object System.Drawing.PointF 300, 110))
$pen = New-Object System.Drawing.Pen (Color '#f2c14e'), 16
$pen.DashStyle = 'Dash'
$pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.DashCap = 'Round'
$g.DrawCurve($pen, $points, 0.6)

# Milestones: filled = done, ringed = next.
$gold = New-Object System.Drawing.SolidBrush (Color '#f2c14e')
$dark = New-Object System.Drawing.SolidBrush (Color '#0b1020')
foreach ($p in @(@(60, 360, $true), @(230, 340, $true), @(120, 220, $true), @(250, 190, $false))) {
	$g.FillEllipse($gold, $p[0] - 20, $p[1] - 20, 40, 40)
	if (-not $p[2]) { $g.FillEllipse($dark, $p[0] - 11, $p[1] - 11, 22, 22) }
}

# The goal: a five-pointed star.
$cx, $cy, $outer, $inner = 300, 105, 62, 26
$star = for ($i = 0; $i -lt 10; $i++) {
	$r = if ($i % 2) { $inner } else { $outer }
	$a = [Math]::PI * (-0.5 + $i / 5)
	New-Object System.Drawing.PointF ($cx + $r * [Math]::Cos($a)), ($cy + $r * [Math]::Sin($a))
}
$g.FillPolygon((New-Object System.Drawing.SolidBrush (Color '#ffe9a8')), [System.Drawing.PointF[]]$star)
$g.DrawPolygon((New-Object System.Drawing.Pen (Color '#f2c14e'), 6), [System.Drawing.PointF[]]$star)

New-Item -ItemType Directory -Force media | Out-Null
$bmp.Save((Join-Path (Get-Location) 'media\logo-400.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output 'media\logo-400.png'
