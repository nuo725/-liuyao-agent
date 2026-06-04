$ErrorActionPreference = 'Stop'

$allowedExtensions = @(
  '.dart', '.md', '.txt', '.yaml', '.yml', '.json', '.js', '.ts', '.html',
  '.css', '.scss', '.sh', '.bat', '.kt', '.java', '.xml', '.gradle',
  '.properties', '.ps1'
)

$trackedFiles = git ls-files | Where-Object {
  $ext = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
  $allowedExtensions -contains $ext
}

function Is-AppRuntimeFile([string]$path) {
  return $path -like 'lib/*'
}

function Is-GovernanceFile([string]$path) {
  return (
    $path -eq 'README.md' -or
    $path -eq 'CHANGELOG.md' -or
    $path -eq 'pubspec.yaml' -or
    $path -eq 'start-all.sh' -or
    $path -eq 'start-all.bat' -or
    $path -like 'docs/*' -or
    $path -like 'tool/*' -or
    $path -eq 'backend/README.md' -or
    $path -eq 'backend/SPEC.md' -or
    $path -eq 'backend/TEST_CHECKLIST.md' -or
    $path -eq 'backend/test.html' -or
    $path -eq 'backend/package.json'
  )
}

$issues = @()

foreach ($file in $trackedFiles) {
  if ($file -like 'backend/node_modules/*') { continue }

  $content = Get-Content -Raw -LiteralPath $file

  if (Is-AppRuntimeFile $file) {
    if ($content -match '\bEN\b') {
      $hits = rg -n '\bEN\b' -- "$file"
      if ($LASTEXITCODE -eq 0 -and $hits) {
        $issues += "[lib placeholder] $hits"
      }
    }
    continue
  }

  if (Is-GovernanceFile $file) {
    if ($content -match '[\u3400-\u9FFF]') {
      $hits = rg -n '[\u3400-\u9FFF]' -- "$file"
      if ($LASTEXITCODE -eq 0 -and $hits) {
        $issues += "[governance CJK] $hits"
      }
    }

    if ($content -match '\bEN\b') {
      $hits = rg -n '\bEN\b' -- "$file"
      if ($LASTEXITCODE -eq 0 -and $hits) {
        $issues += "[governance placeholder] $hits"
      }
    }
  }
}

if ($issues.Count -gt 0) {
  Write-Host 'Text governance check failed:' -ForegroundColor Red
  $issues | ForEach-Object { Write-Host $_ }
  exit 1
}

Write-Host 'Text governance check passed.' -ForegroundColor Green
