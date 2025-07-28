@echo off
echo Cleaning up all offline runners...

REM You need to set REPO_PAT environment variable first
REM set REPO_PAT=your_token_here

curl -s -H "Authorization: token %REPO_PAT%" https://api.github.com/repos/arunprabus/dev2prod-healthapp/actions/runners > runners.json

REM Manual cleanup - get runner IDs and delete them
echo Check runners.json file for IDs and delete manually via GitHub UI
echo Or run: bash cleanup-all-runners.sh