#!/bin/bash
# Clean up all offline runners

REPO="arunprabus/dev2prod-healthapp"
TOKEN="${REPO_PAT}"

echo "Cleaning up all offline runners..."

# Get all runners with "lower" in name
RUNNERS=$(curl -s -H "Authorization: token $TOKEN" https://api.github.com/repos/$REPO/actions/runners | jq -r '.runners[] | select(.name | contains("lower")) | .id')

for runner_id in $RUNNERS; do
    if [ ! -z "$runner_id" ] && [ "$runner_id" != "null" ]; then
        echo "Removing runner ID: $runner_id"
        curl -s -X DELETE -H "Authorization: token $TOKEN" https://api.github.com/repos/$REPO/actions/runners/$runner_id
        sleep 1
    fi
done

echo "Cleanup complete!"