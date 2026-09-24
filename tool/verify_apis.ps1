# MovieGPT — external API verification (TMDB + Gemini).
# SECURITY: reads keys from .env in memory, NEVER prints them, and never
# prints request URLs (they contain the TMDB api_key query param).
$ErrorActionPreference = 'Stop'
# Force TLS 1.2 — some Windows PowerShell sessions negotiate older TLS and
# fail intermittently with "The underlying connection was closed".
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$envMap = @{}
Get-Content (Join-Path $PSScriptRoot '..\.env') | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
    $envMap[$matches[1]] = $matches[2].Trim('"', "'")
  }
}

$tmdbKey     = $envMap['TMDB_API_KEY']
$geminiKey   = $envMap['GEMINI_API_KEY']
$geminiModel = if ($envMap['GEMINI_MODEL']) { $envMap['GEMINI_MODEL'] } else { 'gemini-3.6-flash' }
$aiProvider  = if ($envMap['AI_PROVIDER']) { $envMap['AI_PROVIDER'] } else { 'gemini' }

Write-Output ("CONFIG: TMDB key present: {0}" -f [bool]$tmdbKey)
Write-Output ("CONFIG: GEMINI key present: {0}" -f [bool]$geminiKey)
Write-Output ("CONFIG: AI_PROVIDER: {0}" -f $aiProvider)
Write-Output ("CONFIG: GEMINI_MODEL: {0}" -f $geminiModel)

function Get-TmdbCount([string]$Path, [hashtable]$Query) {
  try {
    $q = $Query.Clone()
    $q['api_key'] = $tmdbKey
    $resp = Invoke-RestMethod -Uri "https://api.tmdb.org/3$Path" -Body $q -Method Get -TimeoutSec 30
    return @{ ok = $true; count = $resp.results.Count; total = $resp.total_results }
  } catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    return @{ ok = $false; status = $code; err = $_.Exception.Message }
  }
}

# 1. Trending (Home -> Trending Today)
$t = Get-TmdbCount '/trending/movie/day' @{ language = 'en-US'; page = 1 }
Write-Output ("TMDB trending/day: ok={0} results={1}" -f $t.ok, $t.count)

# 2. Popular + TopRated (Home -> Recommended For You)
$p = Get-TmdbCount '/movie/popular' @{ language = 'en-US'; page = 1 }
$r = Get-TmdbCount '/movie/top_rated' @{ language = 'en-US'; page = 1 }
Write-Output ("TMDB popular: ok={0} results={1}" -f $p.ok, $p.count)
Write-Output ("TMDB top_rated: ok={0} results={1}" -f $r.ok, $r.count)

# 3. Genre discover (Adventure 12, Action 28, Comedy 35, Drama 18, Sci-Fi 878)
foreach ($g in @(@('Adventure',12), @('Action',28), @('Comedy',35), @('Drama',18), @('Science Fiction',878))) {
  $d = Get-TmdbCount '/discover/movie' @{ with_genres = $g[1]; language = 'en-US'; page = 1; sort_by = 'popularity.desc' }
  if ($d.ok) {
    Write-Output ("TMDB discover {0}: ok=True results={1}" -f $g[0], $d.count)
  } else {
    Write-Output ("TMDB discover {0}: ok=False status={1} err={2}" -f $g[0], $d.status, $d.err)
  }
}

# 4. Search + videos (trailer pipeline) for Interstellar
try {
  $s = Invoke-RestMethod -Uri 'https://api.tmdb.org/3/search/movie' -Body @{ api_key = $tmdbKey; query = 'Interstellar'; language = 'en-US' } -Method Get -TimeoutSec 30
  $first = $s.results | Select-Object -First 1
  Write-Output ("TMDB search 'Interstellar': ok=True total={0} first='{1}' (id {2}, {3})" -f $s.total_results, $first.title, $first.id, $first.release_date)
  $v = Invoke-RestMethod -Uri "https://api.tmdb.org/3/movie/$($first.id)/videos" -Body @{ api_key = $tmdbKey; language = 'en-US' } -Method Get -TimeoutSec 30
  $yt = @($v.results | Where-Object { $_.site -eq 'YouTube' })
  $trailer = $yt | Where-Object { $_.type -eq 'Trailer' -and $_.official } | Select-Object -First 1
  if (-not $trailer) { $trailer = $yt | Where-Object { $_.type -eq 'Trailer' } | Select-Object -First 1 }
  if (-not $trailer) { $trailer = $yt | Select-Object -First 1 }
  if ($trailer) {
    Write-Output ("TMDB videos: ok=True youtubeVideos={0} selected='{1}' type={2} official={3} youtubeKey={4}" -f $yt.Count, $trailer.name, $trailer.type, $trailer.official, $trailer.key)
  } else {
    Write-Output ("TMDB videos: ok=True youtubeVideos=0 selected=<none>")
  }
} catch {
  $code = $null
  if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
  Write-Output ("TMDB search/videos: FAILED status={0} err={1}" -f $code, $_.Exception.Message)
}

# 5. Gemini generateContent (Female Assistant backend)
if ($geminiKey) {
  try {
    $body = @{
      contents = @(@{ role = 'user'; parts = @(@{ text = 'Reply with exactly: OK' }) })
    } | ConvertTo-Json -Depth 6
    $resp = Invoke-RestMethod `
      -Uri "https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent" `
      -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 60 `
      -Headers @{ 'x-goog-api-key' = $geminiKey }
    $text = $resp.candidates[0].content.parts[0].text
    Write-Output ("GEMINI {0}: ok=True replyText='{1}'" -f $geminiModel, ($text.Trim().Substring(0, [Math]::Min(40, $text.Trim().Length))))
  } catch {
    $code = $null
    $detail = ''
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      try {
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $detail = ($sr.ReadToEnd() | ConvertFrom-Json).error.message
      } catch {}
    }
    Write-Output ("GEMINI {0}: ok=False status={1} detail={2}" -f $geminiModel, $code, $detail)
  }
} else {
  Write-Output 'GEMINI: key missing in .env'
}
