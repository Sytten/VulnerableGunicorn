#! /bin/bash
set -e

echo "Building Docker"
docker build . -t 817431877995.dkr.ecr.us-east-1.amazonaws.com/gunicorn-demo > /dev/null

echo "Pushing container"
aws ecr get-login --no-include-email | /bin/bash
docker push 817431877995.dkr.ecr.us-east-1.amazonaws.com/gunicorn-demo:latest

echo "Restarting service"
aws ecs update-service --cluster demo-ecs --service gunicorn-demo --force-new-deployment > /dev/null