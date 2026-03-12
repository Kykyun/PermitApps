#!/bin/bash
echo "🔄 Pulling latest code & restarting AWS server..."
ssh -i ~/perdim/aws.pem ec2-user@47.129.247.210 "cd PermitApps && git pull && docker-compose down && docker-compose up -d --build"
echo "✅ Done!"
