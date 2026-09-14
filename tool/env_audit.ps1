# Env audit - prints ONLY structural facts about .env (never values).
$lines = [System.IO.File]::ReadAllLines((Join-Path $PSScriptRoot '..\.env'))
$i = 0
foreach ($l in $lines) {
  $i++
  $m = [regex]::Match($l, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$')
  if ($m.Success) {
    $k = $m.Groups[1].Value
    $v = $m.Groups[2].Value
    $lead = ($v.Length -gt 0 -and $v[0] -eq ' ')
    $trail = ($v.Length -gt 0 -and ($v[$v.Length-1] -eq ' '))
    $quoted = ($v.StartsWith('"') -or $v.StartsWith("'"))
    Write-Output ("line {0}: key={1} valuelen={2} leadSpace={3} trailSpace={4} quoted={5}" -f $i, $k, $v.Length, $lead, $trail, $quoted)
  } else {
    $trimmed = $l.TrimStart()
    if ($trimmed.Length -eq 0) {
      Write-Output ("line {0}: <blank>" -f $i)
    } elseif ($trimmed.StartsWith('#')) {
      Write-Output ("line {0}: <comment>" -f $i)
    } else {
      Write-Output ("line {0}: <no-key-match> rawlen={1}" -f $i, $l.Length)
    }
  }
}
