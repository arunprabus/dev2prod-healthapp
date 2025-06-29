@echo off
echo Setting up RDS monitoring...

REM Create scheduled task to run every 6 hours
schtasks /create /tn "RDS_Monitor" /tr "bash d:\dev2prod\dev2prod-healthapp\rds-monitor.sh" /sc hourly /mo 6 /f

echo RDS monitoring scheduled every 6 hours
echo Run manually: bash rds-monitor.sh
pause