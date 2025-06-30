#!/bin/bash

# Extract missing AWS permissions from Terraform error logs
# Usage: ./extract-missing-permissions.sh < terraform_error.log

echo "# Missing AWS Permissions Analysis"
echo "# Generated: $(date)"
echo ""

# Extract permission patterns from error messages
grep -oE "not authorized to perform: [a-zA-Z0-9:_-]+" | \
    sed 's/not authorized to perform: //' | \
    sort -u | \
    while read permission; do
        echo "        \"$permission\","
    done | \
    sed '$ s/,$//' > /tmp/permissions.txt

if [ -s /tmp/permissions.txt ]; then
    echo "{"
    echo "    \"Version\": \"2012-10-17\","
    echo "    \"Statement\": ["
    echo "        {"
    echo "            \"Effect\": \"Allow\","
    echo "            \"Action\": ["
    cat /tmp/permissions.txt
    echo "            ],"
    echo "            \"Resource\": \"*\""
    echo "        }"
    echo "    ]"
    echo "}"
else
    echo "No missing permissions found in input"
fi

# Clean up
rm -f /tmp/permissions.txt