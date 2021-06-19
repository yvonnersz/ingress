You may or may not have access to pull my docker image for the hello-scg application
You can create your own or edit the demo-likes-deploy.yml for your application to get started right away

This repo should be used a reference

Please only apply the steps below as an ingress controller and api gateway are already deployed and functional

Steps for succesful deployment to our cluster

Step 1 - deploy.yml and service.yml to k8s cluster (demo-likes-deploy.yml)
Step 2 - verify all routes work, security, and db connections from lb external ip
        Hint -> Check image pull secrets on deploy.yml
        Hint -> Check make sure you have your ci/cd token secret in default namespace
        Hint -> Check all spellings
Step 3 - add routes and mapping to link service to gateway
Step 4 - check ingress controller external ip and verify routes again

If you get stuck reach out

If you have to take a deployment down, make sure to take down the route-config and mapping as well
```
kubectl delete -f route-config.yml
kubectl delete -f mapping.yml
```
Please clean up after yourself

Slides Link:
https://docs.google.com/presentation/d/1FCuw07Zg5rfMMsufVIgZar8DofHOJ74kWDHOOjgId-I/edit?usp=sharing
