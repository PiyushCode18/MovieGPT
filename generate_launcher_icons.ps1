# ============================================================================
# MovieGPT - Premium Circular Launcher Icon Generator
# ----------------------------------------------------------------------------
# Renders a glossy, 3D, Netflix-style circular icon (clapperboard + white play
# button, neon ring, dark purple-black background) at 1024x1024 using GDI+,
# then exports every Android launcher density:
#
#   mipmap-mdpi    -> 48x48
#   mipmap-hdpi    -> 72x72
#   mipmap-xhdpi   -> 96x96
#   mipmap-xxhdpi  -> 144x144
#   mipmap-xxxhdpi -> 192x192
#
# The icon is drawn with a *transparent outside* (perfect circle), so legacy
# (pre-Android-8) launchers display a true circle. Android 8.0+ uses the
# adaptive-icon vector foreground (drawable/ic_launcher_foreground.xml).
#
# GDI+ is vector-accurate against the adaptive foreground XML (same 108-viewport
# geometry, scaled to 1024px) so both layers render identically.
# ============================================================================

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

# Root relative to the script location (project root).
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

# Map a value from the 108-unit vector viewport to a 1024px canvas.
$scale = 1024.0 / 108.0
function S([double]$v) { [double]$v * $scale }

Write-Host 'MovieGPT launcher icon generator' -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Build the 1024x1024 master icon (transparent corners -> perfect circle)
# ---------------------------------------------------------------------------
$size = 1024
$master = New-Object System.Drawing.Bitmap(
    $size,
    $size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$g = [System.Drawing.Graphics]::FromImage($master)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

function New-Color([string]$hex, [byte]$alpha = 255) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    return [System.Drawing.Color]::FromArgb($alpha, $c)
}

$centerX = S(54.0)
$centerY = S(54.0)

# --- Circular background (deep purple-black) ---------------------------------
$bgRadius = S(40.0)
$brushBg = New-Object System.Drawing.SolidBrush((New-Color '#2A1B3F'))
$g.FillEllipse(
    $brushBg,
    [single]($centerX - $bgRadius),
    [single]($centerY - $bgRadius),
    [single]($bgRadius * 2),
    [single]($bgRadius * 2)
)

# --- Neon glow ring (outer violet) -------------------------------------------
$outerR = S(38.5)
$penOuter = New-Object System.Drawing.Pen(
    (New-Color '#8B5CF6'),
    [single](S(3.0))
)
$g.DrawEllipse(
    $penOuter,
    [single]($centerX - $outerR),
    [single]($centerY - $outerR),
    [single]($outerR * 2),
    [single]($outerR * 2)
)

# --- Red accent ring (inner) -------------------------------------------------
$innerR = S(33.0)
$penInner = New-Object System.Drawing.Pen(
    (New-Color '#E50914'),
    [single](S(2.0))
)
$g.DrawEllipse(
    $penInner,
    [single]($centerX - $innerR),
    [single]($centerY - $innerR),
    [single]($innerR * 2),
    [single]($innerR * 2)
)

# --- Fill polygon helper (scales vector coords to 1024) -----------------------
function Add-FilledPolygon($gr, $brush, [double[]]$pts) {
    $count = $pts.Count / 2
    $arr = New-Object 'System.Drawing.PointF[]' $count
    for ($i = 0; $i -lt $pts.Count; $i += 2) {
        $arr[$i / 2] = [System.Drawing.PointF]::new(
            [single](S($pts[$i])),
            [single](S($pts[$i + 1]))
        )
    }
    $gr.FillPolygon($brush, $arr)
}

# --- Clapperboard --------------------------------------------------------------
# Top bar (red)
$brushRed = New-Object System.Drawing.SolidBrush((New-Color '#E50914'))
$g.FillRectangle(
    $brushRed,
    [single](S(35.0)),
    [single](S(42.0)),
    [single](S(38.0)),
    [single](S(9.0))
)

# Stripes (pink / violet / cyan) over the top bar
Add-FilledPolygon $g (New-Object System.Drawing.SolidBrush((New-Color '#D946EF'))) @(35, 42, 42, 35, 51, 35, 44, 42)
Add-FilledPolygon $g (New-Object System.Drawing.SolidBrush((New-Color '#8B5CF6'))) @(47, 42, 54, 35, 63, 35, 56, 42)
Add-FilledPolygon $g (New-Object System.Drawing.SolidBrush((New-Color '#06B6D4'))) @(59, 42, 66, 35, 75, 35, 68, 42)

# Body (dark charcoal)
$brushBody = New-Object System.Drawing.SolidBrush((New-Color '#2A2A2A'))
$g.FillRectangle(
    $brushBody,
    [single](S(35.0)),
    [single](S(51.0)),
    [single](S(38.0)),
    [single](S(16.0))
)

# Body gloss highlight (top 4 units)
$brushGlossBody = New-Object System.Drawing.SolidBrush((New-Color '#3A3A3A'))
$g.FillRectangle(
    $brushGlossBody,
    [single](S(35.0)),
    [single](S(51.0)),
    [single](S(38.0)),
    [single](S(4.0))
)

# Body bottom edge (shadow -> 3D depth)
$brushEdge = New-Object System.Drawing.SolidBrush((New-Color '#1A1A1A'))
$g.FillRectangle(
    $brushEdge,
    [single](S(35.0)),
    [single](S(63.0)),
    [single](S(38.0)),
    [single](S(4.0))
)

# --- Centered white play button ------------------------------------------------
$playPts = @(
    [System.Drawing.PointF]::new([single](S(48.0)), [single](S(56.0))),
    [System.Drawing.PointF]::new([single](S(64.0)), [single](S(63.0))),
    [System.Drawing.PointF]::new([single](S(48.0)), [single](S(70.0)))
)
$playPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$playPath.AddPolygon($playPts)

# Soft dark outline for crispness
$penPlayOutline = New-Object System.Drawing.Pen(
    (New-Color '#000000' 85),
    [single](S(3.0))
)
$penPlayOutline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($penPlayOutline, $playPath)

# White fill
$brushWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillPath($brushWhite, $playPath)

# Mini gloss inside play button
Add-FilledPolygon $g (New-Object System.Drawing.SolidBrush((New-Color '#FFFFFF' 90))) @(50, 57, 61, 62, 50, 67)

# --- Top gloss / reflection crescent -------------------------------------------
$crescent = New-Object System.Drawing.Drawing2D.GraphicsPath
$crescent.AddArc(
    [single](S(54.0 - 34.0)),
    [single](S(40.0 - 34.0)),
    [single](S(68.0)),
    [single](S(68.0)),
    180.0,
    180.0
)
$crescent.AddArc(
    [single](S(54.0 - 30.0)),
    [single](S(40.0 - 30.0)),
    [single](S(60.0)),
    [single](S(60.0)),
    0.0,
    180.0
)
$crescent.CloseFigure()
$brushCrescent = New-Object System.Drawing.SolidBrush((New-Color '#FFFFFF' 15))
$g.FillPath($brushCrescent, $crescent)

$g.Dispose()

# Save the new master source (also used by flutter_launcher_icons).
$masterSource = Join-Path $ProjectRoot 'assets/icon/app_icon.png'
$master.Save($masterSource, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Master icon  -> $masterSource (1024x1024, transparent corners)" -ForegroundColor Green

# Also produce a build copy for the density exports.
$buildDir = Join-Path $ProjectRoot 'build'
if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }
$masterBuild = Join-Path $buildDir 'icon_master.png'
$master.Save($masterBuild, [System.Drawing.Imaging.ImageFormat]::Png)
$master.Dispose()

# ---------------------------------------------------------------------------
# 2. Export mipmap densities (perfect circle, transparent outside)
# ---------------------------------------------------------------------------
function Export-Resized($srcPath, $destPath, $targetSize) {
    $src = [System.Drawing.Image]::FromFile($srcPath)
    $bmp = New-Object System.Drawing.Bitmap(
        $targetSize,
        $targetSize,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $dst = [System.Drawing.Graphics]::FromImage($bmp)
    $dst.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $dst.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $dst.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $dst.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $dst.Clear([System.Drawing.Color]::Transparent)
    $dst.DrawImage($src, 0, 0, $targetSize, $targetSize)
    $dst.Dispose()
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $src.Dispose()
}

$mipmaps = @(
    @{ folder = 'mipmap-mdpi'; size = 48 },
    @{ folder = 'mipmap-hdpi'; size = 72 },
    @{ folder = 'mipmap-xhdpi'; size = 96 },
    @{ folder = 'mipmap-xxhdpi'; size = 144 },
    @{ folder = 'mipmap-xxxhdpi'; size = 192 }
)

foreach ($m in $mipmaps) {
    $dir = Join-Path $ProjectRoot "android/app/src/main/res/$($m.folder)"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $dest = Join-Path $dir 'ic_launcher.png'
    Export-Resized $masterBuild $dest $m.size
    Write-Host "Exported $($m.folder)/ic_launcher.png ($($m.size)x$($m.size))" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3. Remove redundant density-bitmap foregrounds
#    The adaptive icon uses the high-quality VECTOR foreground
#    (drawable/ic_launcher_foreground.xml). The density PNG copies would
#    otherwise override the vector on their densities, so they are removed
#    to guarantee a consistent premium render on every Android 8.0+ device.
# ---------------------------------------------------------------------------
$fgDirs = @('drawable-mdpi', 'drawable-hdpi', 'drawable-xhdpi', 'drawable-xxhdpi', 'drawable-xxxhdpi')
foreach ($d in $fgDirs) {
    $fg = Join-Path $ProjectRoot "android/app/src/main/res/$d/ic_launcher_foreground.png"
    if (Test-Path $fg) {
        Remove-Item -Path $fg -Force
        Write-Host "Removed redundant $d/ic_launcher_foreground.png (vector is used instead)" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Launcher icon regeneration complete.' -ForegroundColor Cyan
