# 小遊戲 3.0 本機伺服器：只對本機（127.0.0.1）開放，從 8730 起找可用的連接埠。關閉視窗即停止。
param([int]$Port = 8730, [switch]$NoBrowser)
$root = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.json'='application/json; charset=utf-8';
  '.css'='text/css; charset=utf-8'; '.glb'='model/gltf-binary'; '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg';
  '.webp'='image/webp'; '.mp4'='video/mp4'; '.ktx2'='image/ktx2'; '.txt'='text/plain; charset=utf-8' }
$listener = $null
for ($p = $Port; $p -lt $Port + 20; $p++) {
  try { $l = New-Object System.Net.HttpListener; $l.Prefixes.Add("http://127.0.0.1:$p/"); $l.Start(); $listener = $l; break } catch { }
}
if (-not $listener) { Write-Host '找不到可用的連接埠。'; exit 1 }
$url = "http://127.0.0.1:$p/"
Write-Host "URL: $url"
Write-Host '小遊戲 3.0 已啟動。關閉這個視窗就會停止。'
if (-not $NoBrowser) { Start-Process $url }
while ($listener.IsListening) {
  try { $ctx = $listener.GetContext() } catch { Write-Host ('接收連線時發生錯誤：' + $_.Exception.Message); if (-not $listener.IsListening) { break }; continue }
  $res = $ctx.Response
  try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($rel -eq '') { $rel = 'index.html' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { $res.StatusCode = 404 }
    else {
      $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()
      $res.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' })
      # Streamed in 64 KiB pieces (no whole-file read). One Range per request (videos seek with it): 206 + Content-Range, at most
      # 1 MiB per answer so a paused video stream cannot hold this single-threaded loop for long; the browser asks for the rest.
      $fs = [IO.File]::Open($full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
      try {
        $len = $fs.Length; $start = [int64]0; $end = $len - 1
        $res.AddHeader('Accept-Ranges', 'bytes')
        $range = $ctx.Request.Headers['Range']
        if ($range -and $range -match '^bytes=(\d*)-(\d*)$' -and ($Matches[1] -ne '' -or $Matches[2] -ne '')) {
          if ($Matches[1] -eq '') { $start = [Math]::Max([int64]0, $len - [int64]$Matches[2]) }
          else { $start = [int64]$Matches[1]; if ($Matches[2] -ne '') { $end = [Math]::Min([int64]$Matches[2], $len - 1) } }
          if ($start -ge $len -or $start -gt $end) { $res.StatusCode = 416; $res.AddHeader('Content-Range', "bytes */$len"); $end = $start - 1 }
          else { $end = [Math]::Min($end, $start + 1048575); $res.StatusCode = 206; $res.AddHeader('Content-Range', "bytes $start-$end/$len") }
        }
        $left = $end - $start + 1; $res.ContentLength64 = $left
        if ($ctx.Request.HttpMethod -ne 'HEAD' -and $left -gt 0) {
          $fs.Position = $start; $buf = New-Object byte[] 65536
          while ($left -gt 0) { $n = $fs.Read($buf, 0, [int][Math]::Min([int64]$buf.Length, $left)); if ($n -le 0) { break }; $res.OutputStream.Write($buf, 0, $n); $left -= $n }
        }
      } finally { $fs.Dispose() }
    }
  } catch { try { $res.StatusCode = 500 } catch { } } finally { try { $res.Close() } catch { } }
}
