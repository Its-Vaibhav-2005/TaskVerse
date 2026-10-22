Add-Type -AssemblyName System.Drawing
$assetPath = Join-Path $PSScriptRoot '..\assets'
[IO.Directory]::CreateDirectory($assetPath) | Out-Null
$bitmap = [Drawing.Bitmap]::new(256,256)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([Drawing.Color]::Transparent)
$shape = [Drawing.Drawing2D.GraphicsPath]::new()
$shape.AddArc(8,8,64,64,180,90)
$shape.AddArc(184,8,64,64,270,90)
$shape.AddArc(184,184,64,64,0,90)
$shape.AddArc(8,184,64,64,90,90)
$shape.CloseFigure()
$brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#394047'))
$graphics.FillPath($brush,$shape)
$pen = [Drawing.Pen]::new([Drawing.Color]::White,15)
$pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
$pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
$points = [Drawing.Point[]]@([Drawing.Point]::new(57,155),[Drawing.Point]::new(103,108),[Drawing.Point]::new(140,138),[Drawing.Point]::new(196,80))
$graphics.DrawLines($pen,$points)
$graphics.DrawLine($pen,162,80,196,80)
$graphics.DrawLine($pen,196,80,196,114)
$pngPath = Join-Path $assetPath 'trackverse.png'
$bitmap.Save($pngPath,[Drawing.Imaging.ImageFormat]::Png)
$png = [IO.File]::ReadAllBytes($pngPath)
$stream = [IO.File]::Create((Join-Path $assetPath 'trackverse.ico'))
$writer = [IO.BinaryWriter]::new($stream)
$writer.Write([UInt16]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]1)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]32)
$writer.Write([UInt32]$png.Length)
$writer.Write([UInt32]22)
$writer.Write($png)
$writer.Dispose()
# Keep web/PWA identity consistent with the Windows and in-app mark.
$webPath = Join-Path $PSScriptRoot '..\web'
foreach ($iconSize in @(192,512)) {
    $resized = [Drawing.Bitmap]::new($iconSize,$iconSize)
    $resizedGraphics = [Drawing.Graphics]::FromImage($resized)
    $resizedGraphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $resizedGraphics.DrawImage($bitmap,0,0,$iconSize,$iconSize)
    $resized.Save((Join-Path $webPath ('icons\Icon-' + $iconSize + '.png')),[Drawing.Imaging.ImageFormat]::Png)
    $resized.Save((Join-Path $webPath ('icons\Icon-maskable-' + $iconSize + '.png')),[Drawing.Imaging.ImageFormat]::Png)
    $resizedGraphics.Dispose()
    $resized.Dispose()
}
$bitmap.Save((Join-Path $webPath 'favicon.png'),[Drawing.Imaging.ImageFormat]::Png)
$pen.Dispose()
$brush.Dispose()
$shape.Dispose()
$graphics.Dispose()
$bitmap.Dispose()
