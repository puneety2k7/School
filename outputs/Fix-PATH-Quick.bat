@echo off
setlocal
title SchoolHub - Quick PostgreSQL PATH fix
set "PGBIN=D:\School Project\Postgresql\bin"
echo Checking %PGBIN%
for %%F in (psql.exe pg_dump.exe pg_restore.exe) do (
  if not exist "%PGBIN%\%%F" (
    echo MISSING: %%F is not in %PGBIN%
    echo Re-run the PostgreSQL installer, tick Command Line Tools, then run this again.
    echo.
    dir /b "%PGBIN%"
    pause
    exit /b 1
  )
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:PGBIN;$u=[Environment]::GetEnvironmentVariable('Path','User');if(-not $u){$u=''};if(($u -split ';') -contains $p){Write-Host 'Already in your PATH.'}else{[Environment]::SetEnvironmentVariable('Path',($u.TrimEnd(';')+';'+$p).TrimStart(';'),'User');Write-Host 'Added to your user PATH.' -ForegroundColor Green}"
echo.
echo Done. Close this window, then run Update-From-Claude-GOVERNANCE-TEST.bat again.
pause
