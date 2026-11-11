# Fills a COPY of the 14-slide template with deck.json. The template itself is opened read-only.
# Usage: powershell -File build.ps1 <renderDir>
param([string]$RenderDir)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Split-Path -Parent $here
$portfolio = Split-Path -Parent $outDir
$caps = Join-Path $outDir 'captures'
$deck = Get-Content (Join-Path $here 'deck.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$tplDir = @(Get-ChildItem $portfolio -Directory | Where-Object { $_.Name -like '002*' })[0].FullName
$tpl = @(Get-ChildItem $tplDir -Filter *.pptx)[0].FullName
$out = Join-Path $outDir ($deck.output + '.pptx')
$pdf = Join-Path $outDir ($deck.output + '.pdf')
Copy-Item $tpl $out -Force
Set-ItemProperty $out -Name IsReadOnly -Value $false

function Px([double]$pt) { return [math]::Round($pt * 4 / 3) }
function Pt([double]$px) { return $px * 3 / 4 }
function Find-Shape($slide, [string]$key) {
  $p = $key.Split(','); $l = [int]$p[0]; $t = [int]$p[1]
  foreach ($s in $slide.Shapes) {
    if ([math]::Abs((Px $s.Left) - $l) -le 2 -and [math]::Abs((Px $s.Top) - $t) -le 2) { return $s }
  }
  return $null
}

$wasRunning = @(Get-Process POWERPNT -ErrorAction SilentlyContinue).Count
$pp = New-Object -ComObject PowerPoint.Application
$pres = $pp.Presentations.Open($out, 0, 0, 0)
$dark = 0x383C14   # RGB(20,60,56) as BGR integer
$missing = @()
foreach ($prop in $deck.slides.PSObject.Properties) {
  $n = [int]$prop.Name; $spec = $prop.Value; $slide = $pres.Slides.Item($n)
  if ($spec.text) {
    foreach ($t in $spec.text.PSObject.Properties) {
      $s = Find-Shape $slide $t.Name
      if ($null -eq $s) { $missing += "slide $n text $($t.Name)"; continue }
      $s.TextFrame.TextRange.Text = ($t.Value -replace "`n", "`r")
    }
  }
  if ($spec.table) {
    $tbl = $null
    foreach ($s in $slide.Shapes) { if ($s.HasTable) { $tbl = $s } }
    if ($null -eq $tbl) { $missing += "slide $n table" } else {
      $height = $tbl.Height
      $rows = @($spec.table)
      while ($tbl.Table.Rows.Count -lt ($rows.Count + 1)) { [void]$tbl.Table.Rows.Add() }
      while ($tbl.Table.Rows.Count -gt ($rows.Count + 1)) { $tbl.Table.Rows.Item($tbl.Table.Rows.Count).Delete() }
      for ($r = 0; $r -lt $rows.Count; $r++) {
        $cells = @($rows[$r])
        for ($c = 0; $c -lt $cells.Count; $c++) {
          $tr = $tbl.Table.Cell($r + 2, $c + 1).Shape.TextFrame.TextRange
          $tr.Text = [string]$cells[$c]
          if ($spec.tableFont) { $tr.Font.Size = [double]$spec.tableFont }
        }
      }
      $rh = $height / $tbl.Table.Rows.Count
      for ($r = 1; $r -le $tbl.Table.Rows.Count; $r++) { $tbl.Table.Rows.Item($r).Height = $rh }
    }
  }
  if ($spec.delete) {
    foreach ($key in @($spec.delete)) {
      $s = Find-Shape $slide $key
      if ($null -eq $s) { $missing += "slide $n delete $key" } else { $s.Delete() }
    }
  }
  if ($spec.pictures) {
    foreach ($p in @($spec.pictures)) {
      $file = Join-Path $caps $p.file
      $pic = $slide.Shapes.AddPicture($file, 0, -1, (Pt $p.left), (Pt $p.top))
      $pic.LockAspectRatio = -1
      $pic.Height = Pt $p.height
      $pic.Left = Pt $p.left; $pic.Top = Pt $p.top
      $pic.Line.Visible = -1; $pic.Line.ForeColor.RGB = 0xCCD8CF; $pic.Line.Weight = 0.75
      $pic.AlternativeText = [string]$p.file
    }
  }
  if ($spec.boxes) {
    foreach ($b in @($spec.boxes)) {
      $box = $slide.Shapes.AddTextbox(1, (Pt $b.left), (Pt $b.top), (Pt $b.width), (Pt $b.height))
      $box.TextFrame.WordWrap = -1
      $box.TextFrame.AutoSize = 0
      $tr = $box.TextFrame.TextRange
      $tr.Text = ($b.text -replace "`n", "`r")
      $tr.Font.Size = [double]$b.size
      $tr.Font.Color.RGB = $dark
      if ($b.mono) { $tr.Font.Name = 'Consolas'; $tr.Font.NameFarEast = 'Malgun Gothic' }
      $tr.ParagraphFormat.Alignment = 1
      $tr.ParagraphFormat.SpaceWithin = 1.15
    }
  }
}
$pres.Save()
$pres.SaveAs($pdf, 32)
if ($RenderDir) {
  New-Item -ItemType Directory -Force $RenderDir | Out-Null
  for ($i = 1; $i -le $pres.Slides.Count; $i++) { $pres.Slides.Item($i).Export((Join-Path $RenderDir ("out-{0:d2}.png" -f $i)), 'PNG', 1280, 720) }
}
$pres.Close()
if ($wasRunning -eq 0) { $pp.Quit() }
"slides: 14, missing: $($missing.Count)"; $missing
Get-ChildItem $outDir -File | Select-Object Name, Length
