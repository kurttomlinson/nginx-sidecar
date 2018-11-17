# Build and push Docker image
```
docker build -t 541693649649.dkr.ecr.us-east-1.amazonaws.com/nginx-sidecar .
docker push 541693649649.dkr.ecr.us-east-1.amazonaws.com/nginx-sidecar
```

# Create docker image repository (ONE TIME ONLY! DON'T DO THIS!)
```
aws ecr create-repository --repository-name nginx-sidecar
```
