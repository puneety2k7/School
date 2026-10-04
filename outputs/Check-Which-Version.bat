@echo off
setlocal
title SchoolHub - Which version is installed?
set "REPO=%~dp0..\github-upload-current"
if not exist "%REPO%\.git" (
  echo Could not find github-upload-current next to this folder.
  echo Put this file inside the Claude-App-Updater folder and run it again.
  pause
  exit /b 1
)
echo ===== CODE =====
git -C "%REPO%" branch --show-current
git -C "%REPO%" log -1 --oneline
echo.
echo Expected: refactor/universal-governance  and  3c55473 Make universal workspace permissions the sole operational authorization source
echo.
echo ===== SERVER =====
powershell.exe -NoProfile -Command "try{$r=Invoke-RestMethod 'http://127.0.0.1:8080/health' -TimeoutSec 5;Write-Host ('Server on port 8080 answered: '+($r|ConvertTo-Json -Compress))}catch{try{$r=Invoke-RestMethod 'http://127.0.0.1:3000/health' -TimeoutSec 5;Write-Host ('API answered: '+($r|ConvertTo-Json -Compress))}catch{Write-Host 'Server NOT answering - the app is not running.' -ForegroundColor Red}}"
echo.
echo ===== DATABASE =====
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$cfg=@{};Get-Content '%REPO%\schoolhub.config.env' -Encoding UTF8 | ForEach-Object{ if($_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$'){ $cfg[$Matches[1]]=$Matches[2].Trim().Trim('\"') } };$env:PGPASSWORD=$cfg['POSTGRES_PASSWORD'];$h=$cfg['POSTGRES_HOST'];if(-not $h){$h='127.0.0.1'};$out=& psql -h $h -p $cfg['POSTGRES_PORT'] -U $cfg['POSTGRES_USER'] -d $cfg['POSTGRES_DATABASE'] -t -A -c 'select version||\" \"||name from migration_history order by version desc limit 1' 2>&1;Write-Host ('Latest migration: '+$out);Write-Host 'Expected: 51 convert_legacy_role_grants_to_universal_permissions'"
echo.
pause
