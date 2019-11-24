# VulnerableGunicorn

This is a simple application and infrastructure to test HTTP Desync Attacks against Gunicorn+Flask running in ECS behind an AWS ALB.

The whole process is detailed in my [blog post](https://medium.com/@emilefugulin/http-desync-attacks-with-python-and-aws-1ba07d2c860f).

## Deploy
1. In the infra folder, `terraform apply`
2. Change the AWS account ID in the `deploy.sh` script
3. `./deploy.sh`

## Thanks
The application is largely inspired by code used in the blog post [HAProxy HTTP request smuggling](https://nathandavison.com/blog/haproxy-http-request-smuggling).