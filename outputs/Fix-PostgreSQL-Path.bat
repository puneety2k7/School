@echo off
setlocal
title SchoolHub - Fix PostgreSQL PATH
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$roots=@($env:ProgramFiles,${env:ProgramFiles(x86)},'C:\PostgreSQL','D:\PostgreSQL','D:\Program Files\PostgreSQL','E:\PostgreSQL') | Where-Object { $_ -and (Test-Path $_) };" ^
 "$bins=@();foreach($r in $roots){$base=if((Split-Path $r -Leaf) -eq 'PostgreSQL'){$r}else{Join-Path $r 'PostgreSQL'};if(Test-Path $base){Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | ForEach-Object{$b=Join-Path $_.FullName 'bin';if((Test-Path (Join-Path $b 'psql.exe')) -and (Test-Path (Join-Path $b 'pg_dump.exe')) -and (Test-Path (Join-Path $b 'pg_restore.exe'))){$bins+=[pscustomobject]@{Path=$b;Ver=$_.Name}}}}};" ^
 "if(-not $bins){Write-Host 'NOT FOUND: PostgreSQL command-line tools (psql, pg_dump, pg_restore) were not found in the usual folders.' -ForegroundColor Red;Write-Host 'Re-run the PostgreSQL installer and tick Command Line Tools, or tell Claude where PostgreSQL is installed.';exit 1};" ^
 "$pick=($bins | Sort-Object {[double]($_.Ver -replace '[^0-9.]','')} -Descending | Select-Object -First 1).Path;" ^
 "Write-Host ('Found: '+$pick) -ForegroundColor Green;" ^
 "$user=[Environment]::GetEnvironmentVariable('Path','User');if(-not $user){$user=''};" ^
 "if(($user -split ';') -contains $pick){Write-Host 'Already in your PATH.'}else{[Environment]::SetEnvironmentVariable('Path',($user.TrimEnd(';')+';'+$pick).TrimStart(';'),'User');Write-Host 'Added to your user PATH.' -ForegroundColor Green};" ^
 "Write-Host '';Write-Host 'Close this window, then run Update-From-Claude-GOVERNANCE-TEST.bat again.'"
if errorlevel 1 (
  echo.
  pause
  exit /b 1
)
echo.
pause
exit /b 0
