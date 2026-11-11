# Writes notes.json into the speaker notes of the existing portfolio deck (slides themselves are not changed).
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Split-Path -Parent $here
$deck = Get-Content (Join-Path $here 'deck.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$notes = Get-Content (Join-Path $here 'notes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$out = Join-Path $outDir ($deck.output + '.pptx')
$wasRunning = @(Get-Process POWERPNT -ErrorAction SilentlyContinue).Count
$pp = New-Object -ComObject PowerPoint.Application
$pres = $pp.Presentations.Open($out, 0, 0, 0)
$done = 0
foreach ($p in $notes.PSObject.Properties) {
  $slide = $pres.Slides.Item([int]$p.Name)
  $body = $null
  foreach ($s in $slide.NotesPage.Shapes) {
    if ($s.Type -eq 14 -and $s.PlaceholderFormat.Type -eq 2) { $body = $s }
  }
  if ($null -eq $body) { "no notes body on slide $($p.Name)"; continue }
  $body.TextFrame.TextRange.Text = [string]$p.Value
  $done++
}
$pres.Save()
$check = @()
for ($i = 1; $i -le $pres.Slides.Count; $i++) {
  foreach ($s in $pres.Slides.Item($i).NotesPage.Shapes) {
    if ($s.Type -eq 14 -and $s.PlaceholderFormat.Type -eq 2) { $check += $s.TextFrame.TextRange.Text.Length }
  }
}
$pres.Close()
if ($wasRunning -eq 0) { $pp.Quit() }
"notes written: $done"; "lengths: " + ($check -join ',')
