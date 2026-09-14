# Diagnostic: check whether the FIREBASE project API key (google-services.json)
# is authorized for the Generative Language API. The key is read in memory and
# NEVER printed. This only reports the HTTP status / Google error message.
$ErrorActionPreference = 'Stop'
$gs = Get-Content (Join-Path $PSScriptRoot '..\android\app\google-services.json') -Raw | ConvertFrom-Json
$fbKey = $gs.client[0].api_key[0].current_key
Write-Output ("FIREBASE key present: {0}" -f [bool]$fbKey)
try {
  $body = @{ contents = @(@{ role = 'user'; parts = @(@{ text = 'Reply with exactly: OK' }) }) } | ConvertTo-Json -Depth 6
  $resp = Invoke-RestMethod `
    -Uri 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent' `
    -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 60 `
    -Headers @{ 'x-goog-api-key' = $fbKey }
  $text = $resp.candidates[0].content.parts[0].text
  Write-Output ("FIREBASE key vs Gemini: HTTP 200, reply='{0}'" -f $text.Trim().Substring(0, [Math]::Min(20, $text.Trim().Length)))
} catch {
  $code = $null; $detail = ''
  if ($_.Exception.Response) {
    $code = [int]$_.Exception.Response.StatusCode
    try {
      $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $detail = ($sr.ReadToEnd() | ConvertFrom-Json).error.message
    } catch {}
  }
  Write-Output ("FIREBASE key vs Gemini: HTTP {0} - {1}" -f $code, $detail)
}
