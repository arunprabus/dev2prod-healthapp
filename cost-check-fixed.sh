#!/bin/bash

# Fixed cost checking script
END_DATE=$(date +%Y-%m-%d)
START_DATE=$(date -d '7 days ago' +%Y-%m-%d)

echo "Checking costs from $START_DATE to $END_DATE"

# Get cost data and save to file
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json > cost-report.json

# Check if file has data
if [ ! -s cost-report.json ]; then
  echo "No cost data retrieved"
  exit 0
fi

# Extract total cost (all services)
TOTAL_COST=$(jq -r '.ResultsByTime[].Total.BlendedCost.Amount // "0"' cost-report.json | awk '{sum += $1} END {print sum+0}')

echo "Weekly Total Cost: \$${TOTAL_COST}"

# Check if cost exceeds threshold
if (( $(echo "$TOTAL_COST > 1" | bc -l 2>/dev/null || echo "0") )); then
  echo "⚠️ Cost Alert: Weekly spend exceeded \$1"
  echo "Expected: \$0 (Free Tier)"
  exit 1
else
  echo "✅ Cost within expected range (\$0 Free Tier)"
fi

# Show breakdown by service
echo ""
echo "Cost breakdown by service:"
jq -r '.ResultsByTime[].Groups[]? | "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount)"' cost-report.json 2>/dev/null || echo "No service breakdown available"