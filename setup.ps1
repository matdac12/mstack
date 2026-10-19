<#
.SYNOPSIS
  Clone the mstack tools into place and, optionally, link the skills into your agents.

.DESCRIPTION
  Reads tools.json and clones every tool that is not already next to this script.
  Tools that are already there are left alone; their branch and state are reported.
  With -Skills, each folder in skills\ is linked (as a directory junction) into
  ~\.claude\skills and ~\.agents\skills. Existing entries are never overwritten.

.EXAMPLE
  .\setup.ps1
  .\setup.ps1 -Only parla,hyperkey
  .\setup.ps1 -Skills
#>
[CmdletBinding()]
param(
  [string[]]$Only,
  [switch]$Skills
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'git is not on PATH. Install Git for Windows first: https://git-scm.com/download/win'
}

$tools = (Get-Content (Join-Path $root 'tools.json') -Raw | ConvertFrom-Json).tools
if ($Only) {
  $unknown = $Only | Where-Object { $_ -notin $tools.name }
  if ($unknown) { throw "Unknown tool(s): $($unknown -join ', '). Known: $($tools.name -join ', ')" }
  $tools = $tools | Where-Object { $_.name -in $Only }
}

Write-Host "`nTools" -ForegroundColor Cyan
foreach ($tool in $tools) {
  $dir = Join-Path $root $tool.name
  if (Test-Path (Join-Path $dir '.git')) {
    $branch = git -C $dir branch --show-current
    $dirty = git -C $dir status --porcelain
    $state = if ($dirty) { 'uncommitted changes' } else { 'clean' }
    Write-Host ("  {0,-10} present  ({1}, {2})" -f $tool.name, $branch, $state)
  }
  elseif (Test-Path $dir) {
    Write-Warning "$($tool.name): $dir exists but is not a git repo; skipped."
  }
  else {
    Write-Host ("  {0,-10} cloning  {1}" -f $tool.name, $tool.repo)
    git clone --quiet "$($tool.repo).git" $dir
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $($tool.name)" }
  }
}

if ($Skills) {
  $targets = @(
    (Join-Path $HOME '.claude\skills'),
    (Join-Path $HOME '.agents\skills')
  )
  Write-Host "`nSkills" -ForegroundColor Cyan
  foreach ($skill in Get-ChildItem (Join-Path $root 'skills') -Directory) {
    foreach ($target in $targets) {
      New-Item -ItemType Directory -Force -Path $target | Out-Null
      $link = Join-Path $target $skill.Name
      $existing = Get-Item $link -Force -ErrorAction SilentlyContinue
      if (-not $existing) {
        New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
        Write-Host ("  {0,-10} linked   {1}" -f $skill.Name, $link)
      }
      elseif ($existing.Target -and ((@($existing.Target)[0] -replace '^\\\\\?\\', '').TrimEnd('\') -eq $skill.FullName.TrimEnd('\'))) {
        Write-Host ("  {0,-10} ok       {1}" -f $skill.Name, $link)
      }
      else {
        Write-Warning "$($skill.Name): $link already exists and points elsewhere; left as is."
      }
    }
  }
}

Write-Host "`nDone. Each tool's README has its own build and install steps." -ForegroundColor Green
