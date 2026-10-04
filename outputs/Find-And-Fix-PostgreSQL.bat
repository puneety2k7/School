@echo off
setlocal
title SchoolHub - Find PostgreSQL
echo Searching for PostgreSQL. This can take 1-3 minutes...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$dirs=New-Object System.Collections.Generic.List[string];" ^
 "Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'postgres' } | ForEach-Object { Write-Host ('Service: '+$_.Name+'  '+$_.PathName); if($_.PathName -match '\"?([^\"]*?)\\postgres\.exe'){ $dirs.Add($Matches[1]) } };" ^
 "foreach($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null })){ Get-ChildItem -Path $d.Root -Filter pg_dump.exe -Recurse -ErrorAction SilentlyContinue -Force | ForEach-Object { $dirs.Add($_.DirectoryName) } };" ^
 "$good=@($dirs | Select-Object -Unique | Where-Object { (Test-Path (Join-Path $_ 'psql.exe')) -and (Test-Path (Join-Path $_ 'pg_dump.exe')) -and (Test-Path (Join-Path $_ 'pg_restore.exe')) });" ^
 "Write-Host '';" ^
 "if(-not $good){ Write-Host 'Folders found with pg_dump.exe:'; $dirs | Select-Object -Unique | ForEach-Object { Write-Host ('  '+$_) }; Write-Host 'NO complete set (psql + pg_dump + pg_restore) was found. Re-run the PostgreSQL installer and tick Command Line Tools, then run this again. Send Claude a screenshot of this window.' -ForegroundColor Red; exit 1 };" ^
 "$pick=$good | Sort-Object -Descending | Select-Object -First 1; Write-Host ('Using: '+$pick) -ForegroundColor Green;" ^
 "$user=[Environment]::GetEnvironmentVariable('Path','User'); if(-not $user){$user=''};" ^
 "if(($user -split ';') -contains $pick){ Write-Host 'Already in your PATH.' } else { [Environment]::SetEnvironmentVariable('Path',($user.TrimEnd(';')+';'+$pick).TrimStart(';'),'User'); Write-Host 'Added to your user PATH.' -ForegroundColor Green };" ^
 "Write-Host ''; Write-Host 'Close this window, then run Update-From-Claude-GOVERNANCE-TEST.bat again.'"
echo.
pause
