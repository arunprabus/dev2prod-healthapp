#!/bin/bash
# Restart runner by rebooting instance
aws ec2 reboot-instances --instance-ids i-02af40a6a15399d46 --region ap-south-1
echo "Runner rebooted. Wait 3-5 minutes for GitHub registration."