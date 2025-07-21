@echo off
cd %~dp0
echo Running Terraform validation...
terraform validate
if %ERRORLEVEL% NEQ 0 (
  echo Validation failed!
) else (
  echo Validation successful!
)
pause