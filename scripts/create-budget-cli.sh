#!/bin/bash

# Create Budget via CLI - Standalone Script
# Usage: ./create-budget-cli.sh [email] [amount] [budget-name]

EMAIL=${1:-"admin@example.com"}
AMOUNT=${2:-"1.00"}
BUDGET_NAME=${3:-"CLI-Budget-Alert"}

echo "🛡️ Creating budget: $BUDGET_NAME"
echo "📧 Email: $EMAIL"
echo "💰 Amount: \$$AMOUNT"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "🏦 Account ID: $ACCOUNT_ID"

# Create the budget
aws budgets create-budget \
  --account-id $ACCOUNT_ID \
  --budget "{
    \"BudgetName\": \"$BUDGET_NAME\",
    \"BudgetLimit\": {
      \"Amount\": \"$AMOUNT\",
      \"Unit\": \"USD\"
    },
    \"TimeUnit\": \"MONTHLY\",
    \"BudgetType\": \"COST\"
  }" \
  --notifications-with-subscribers "[
    {
      \"Notification\": {
        \"NotificationType\": \"ACTUAL\",
        \"ComparisonOperator\": \"GREATER_THAN\",
        \"Threshold\": 80,
        \"ThresholdType\": \"PERCENTAGE\"
      },
      \"Subscribers\": [
        {
          \"SubscriptionType\": \"EMAIL\",
          \"Address\": \"$EMAIL\"
        }
      ]
    },
    {
      \"Notification\": {
        \"NotificationType\": \"FORECASTED\",
        \"ComparisonOperator\": \"GREATER_THAN\",
        \"Threshold\": 100,
        \"ThresholdType\": \"PERCENTAGE\"
      },
      \"Subscribers\": [
        {
          \"SubscriptionType\": \"EMAIL\",
          \"Address\": \"$EMAIL\"
        }
      ]
    }
  ]"

if [ $? -eq 0 ]; then
  echo "✅ Budget '$BUDGET_NAME' created successfully!"
  echo "📧 You'll receive alerts at 80% and 100% of \$$AMOUNT"
  echo "🔍 View at: https://console.aws.amazon.com/billing/home#/budgets"
else
  echo "❌ Failed to create budget (may already exist)"
fi

# List all budgets
echo ""
echo "📋 Current budgets:"
aws budgets describe-budgets --account-id $ACCOUNT_ID --query 'Budgets[].[BudgetName,BudgetLimit.Amount]' --output table