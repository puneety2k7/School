param([switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Join-Path $workspaceRoot 'github-upload-current'
$repositoryWindows = Join-Path $repositoryRoot 'deployment\windows'
$privateConfig = Join-Path $repositoryRoot 'schoolhub.config.env'
$oldConfig = Join-Path $workspaceRoot 'schoolhub.config.env'
$updateLogs = Join-Path $workspaceRoot 'claude-update-logs'
$updateLog = Join-Path $updateLogs ('update-governance-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
$stagingRoot = Join-Path $workspaceRoot ('SchoolHub-update-staging-' + $PID)
$stagingAdded = $false
$step = 'Initialization'
$testBranch = 'refactor/universal-governance'

New-Item -ItemType Directory -Path $updateLogs -Force | Out-Null
Start-Transcript -LiteralPath $updateLog | Out-Null

function Invoke-Checked {
  param([string]$Command, [string[]]$Arguments, [string]$Failure)
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw $Failure }
}

try {
  $step = 'Prerequisites'
  if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot '.git'))) {
    throw "REPOSITORY_NOT_FOUND: Expected the Git-connected app at $repositoryRoot"
  }
  foreach ($name in @('git', 'node', 'npm.cmd', 'python')) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
      throw "PREREQUISITE_MISSING: $name was not found."
    }
  }
  $nodeMajor = [int]((& node --version).TrimStart('v').Split('.')[0])
  if ($nodeMajor -lt 22) { throw 'NODE_VERSION: Node.js 22 or newer is required.' }

  $step = 'Private configuration'
  if (-not (Test-Path -LiteralPath $privateConfig)) {
    if (Test-Path -LiteralPath $oldConfig) {
      Copy-Item -LiteralPath $oldConfig -Destination $privateConfig
      Write-Host 'Copied the existing private configuration into the Git-connected installation.'
    } else {
      Copy-Item -LiteralPath (Join-Path $repositoryRoot 'schoolhub.config.env.example') -Destination $privateConfig
      throw "CONFIG_CREATED: Edit $privateConfig, replace CHANGE_ME, then double-click Update-From-Claude.bat again."
    }
  }

  $step = 'Repository checks'
  Push-Location $repositoryRoot
  try {
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or ($branch -ne 'main' -and $branch -ne $testBranch)) {
      throw "GIT_BRANCH: Expected main or $testBranch but found '$branch'."
    }
    $trackedChanges = @(& git status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0) { throw 'GIT_STATUS_FAILED: Could not inspect the repository.' }
    if ($trackedChanges.Count -gt 0) {
      throw 'LOCAL_CHANGES: Claude or another tool has uncommitted tracked changes in the local repository. Finish or preserve them before updating.'
    }
    $remote = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $remote -notmatch 'github\.com[/:]puneety2k7/Schoolhub-app\.(?:\.git)?$') {
      throw "GIT_REMOTE: Unexpected origin URL '$remote'."
    }

    $step = 'Download update information'
    Invoke-Checked 'git' @('fetch', '--prune', 'origin', $testBranch) 'GIT_FETCH_FAILED: Could not download the test branch.'
    $currentCommit = (& git rev-parse HEAD).Trim()
    $targetCommit = (& git rev-parse "origin/$testBranch").Trim()
    if ($branch -eq $testBranch) {
      Invoke-Checked 'git' @('merge-base', '--is-ancestor', 'HEAD', "origin/$testBranch") 'NON_FAST_FORWARD: Local test branch and GitHub have diverged. Manual review is required.'
    }

    if ($currentCommit -ne $targetCommit -or $branch -ne $testBranch) {
      $step = 'Isolated build and tests'
      Invoke-Checked 'git' @('worktree', 'add', '--detach', $stagingRoot, "origin/$testBranch") 'STAGING_FAILED: Could not create the isolated test copy.'
      $stagingAdded = $true
      Push-Location (Join-Path $stagingRoot 'schoolhub-server')
      try {
        Invoke-Checked 'npm.cmd' @('ci') 'NPM_INSTALL_FAILED: The proposed update dependencies could not be installed.'
        Invoke-Checked 'npm.cmd' @('run', 'build') 'BUILD_FAILED: The proposed update did not compile.'
        Invoke-Checked 'npm.cmd' @('test') 'TEST_FAILED: The proposed update did not pass automated tests.'
      } finally {
        Pop-Location
      }
      Invoke-Checked 'git' @('worktree', 'remove', '--force', $stagingRoot) 'STAGING_CLEANUP_FAILED: Could not remove the isolated test copy.'
      $stagingAdded = $false

      $step = 'Stop the current app'
      $newStop = Join-Path $repositoryWindows 'Stop-SchoolHub.ps1'
      & $newStop -RuntimeDirectory (Join-Path $repositoryRoot 'logs')
      if ($LASTEXITCODE -ne 0) { throw 'STOP_FAILED: The Git-connected installation could not be stopped safely.' }
      $oldStop = Join-Path $workspaceRoot 'deployment\windows\Stop-SchoolHub.ps1'
      if (Test-Path -LiteralPath $oldStop) {
        & $oldStop -RuntimeDirectory (Join-Path $workspaceRoot 'logs')
        if ($LASTEXITCODE -ne 0) { throw 'OLD_STOP_FAILED: The previous installation could not be stopped safely.' }
      }

      $step = 'Install tested commit'
      Invoke-Checked 'git' @('checkout', '-B', $testBranch, "origin/$testBranch") 'GIT_UPDATE_FAILED: Could not switch to the tested governance branch.'
    } else {
      Write-Host 'The GitHub code is already up to date.' -ForegroundColor Green
    }
  } finally {
    Pop-Location
  }

  $step = 'Backup, migrate, and start'
  & (Join-Path $repositoryWindows 'Setup-SchoolHub.ps1') -ConfigPath $privateConfig -SkipTests -NoBrowser:$NoBrowser
  if ($LASTEXITCODE -ne 0) { throw 'SETUP_FAILED: SchoolHub setup did not finish. Review its setup log before retrying.' }

  Write-Host 'GOVERNANCE TEST BRANCH installed. To return to main later run: git checkout main (in the github-upload-current folder).' -ForegroundColor Green
  Write-Host "Installed commit: $targetCommit"
  Write-Host 'Application: http://127.0.0.1:8080/SchoolHub_School_Management_App_Complete.html'
  Write-Host "Update log: $updateLog"
} catch {
  $safeMessage = ($_.Exception.Message -replace 'postgresql://[^\s]+', '[REDACTED_DATABASE_URL]' -replace '(?i)(password\s*[=:]\s*)[^;\s]+', '$1[REDACTED]')
  Write-Host "FAILED STEP: $step" -ForegroundColor Red
  Write-Host "ERROR: $safeMessage" -ForegroundColor Red
  Write-Host "LOG: $updateLog"
  exit 1
} finally {
  if ($stagingAdded) {
    Push-Location $repositoryRoot
    try { & git worktree remove --force $stagingRoot 2>$null | Out-Null } catch {}
    Pop-Location
  }
  try { Stop-Transcript | Out-Null } catch {}
}
