# UPDATES!
* Slides Link:
https://docs.google.com/presentation/d/1FCuw07Zg5rfMMsufVIgZar8DofHOJ74kWDHOOjgId-I/edit?usp=sharing

* These Slides are for creating a spring cloud gateway instance in k8s.

* If you are looking for App Deployment info please continue with the readme.
# App Deployment

_**This readme assumes you have aws-cli and kubectl set up in your shell**_

If you are on your main branch, checkout a new branch named: _deploy_

If you are on any other branch you should be fine

## Step 1: Double Check your application dependencies

_application.properties_
```properties
#K8s
spring.application.name=likes-api
spring.cloud.gateway.discovery.locator.enabled=true
spring.cloud.kubernetes.discovery.all-namespaces=true
spring.cloud.kubernetes.loadbalancer.mode=SERVICE
management.endpoints.web.exposure.include=health

# other properties below
```
Make sure you have all of these in your application.properties files

---
## Step 2: Double Check your .gitlab-ci.yml

_.gitlab-ci.yml_
```yml
stages:
  - build
  - test
  - coverage
  - docker
  - deploy
build:
  image: adoptopenjdk:11
  stage: build
  script:
    - ./gradlew bootJar
  cache:
    key: GRADLE-BUILD-FILES
    paths:
      - build/
  artifacts:
    paths:
      - build/classes/java/
      - build/libs/*.jar
test:
  image: adoptopenjdk:11
  needs:
    - build
  stage: test
  script:
    ./gradlew test
  artifacts:
    paths:
      - build/classes/java/
      - build/test-results/test/*.xml
coverage:
  image: adoptopenjdk:11
  needs:
    - build
    - test
  stage: coverage
  script:
    - ./gradlew jacocoTestReport
    - ./gradlew jacocoTestCoverageVerification
  allow_failure: true
  artifacts:
    when: always
    paths:
      - build/reports/jacoco/
docker:
  image: docker:20
  needs:
    - build
    - test
  stage: docker
  services:
    - docker:dind
  before_script:
    - echo "$MY_NAME"
    - echo $CI_BUILD_TOKEN | docker login -u "$CI_REGISTRY_USER" --password-stdin $CI_REGISTRY
  script:
    - docker build --pull -t "$CI_REGISTRY_IMAGE":"$CI_PIPELINE_IID" .
    - docker push "$CI_REGISTRY_IMAGE":"$CI_PIPELINE_IID"
    - docker tag "$CI_REGISTRY_IMAGE":"$CI_PIPELINE_IID" "$CI_REGISTRY_IMAGE":"latest"
    - docker push "$CI_REGISTRY_IMAGE":"latest"
deploy:
  stage: deploy
  image: registry.gitlab.com/galv-vmw-apr-2021/capstone/base-aws-eks-image:latest
  needs:
    - build
    - test
    - docker
  before_script:
    - export IMAGE="$CI_REGISTRY_IMAGE":"$CI_PIPELINE_IID"
    - aws configure set region us-west-2
    - aws configure set output json
    - aws eks update-kubeconfig --name "$CLUSTER_NAME"
    - aws sts get-caller-identity

  script: # we will create the files below in the next few steps

    - envsubst < your-app-deploy.yml | kubectl apply -f -
    - kubectl apply -f your-app-routes-maps.yml
  only: # this will only run the deploy stage on main
    - main
```
---
## Step 3: Make a Dockerfile

_Dockerfile_
```Dockerfile
FROM adoptopenjdk:11
WORKDIR /app
COPY build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
EXPOSE 8080
```

At this stage you should make a commit with any of the changes you have made.

 Run your tests and push to gitlab, you should not be on your main branch so the deploy stage will not run in gitlab.

 ---

 ## Step 4: Create your deployment and service yml(s)

 This can be created in two separate files, just make sure you include them in the deployment section of your _.gitlab-ci.yml_

 For the sake of this exercise, these will be combined

 Add this file to your root

_appname-deploy.yml_
``` yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appname-api #change me
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: appname-api #change me
  template:
    metadata:
      labels:
        app: appname-api #change me
        namespace: default
    spec:
      serviceAccountName: api-service-acount
      containers:
      # replace the line below with the image from your container registry in gitlab
        - image: registry.gitlab.com/galv-vmw-apr-2021/capstone/tough-cookies/likes:latest #change me
          name: likes-api
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: bakery-db-secrets
                  key: DB_HOST
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: bakery-db-secrets
                  key: DB_NAME
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: bakery-db-secrets
                  key: DB_USER
            - name: DB_PWD
              valueFrom:
                secretKeyRef:
                  name: bakery-db-secrets
                  key: DB_PWD
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: jwt-key-secret
                  key: JWT_SECRET_KEY
      imagePullSecrets: # we will create this token in the next step
        - name: appname-api-token #change me
---
apiVersion: v1
kind: Service
metadata:
# our convention is appname-api-lb for service name
  name: appname-api-lb #change me
  namespace: default
spec:
  type: LoadBalancer
  selector: # below should be the same as line 4
    app: appname-api #change me
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      name: http
```

* A great convention is to name your deployment app names like such "appname-api" for the deployment

* "appname-api-lb" for service

  * ie. _"likes-api"_

* this will keep our namespace clear and distinct

Make sure you replace the image with the image from your gitlab registry!!

---

## Image Pull Secrets

1. Go to your deployment repo in gitlab
2. Go to Settings -> Reposity -> Deploy Tokens
3. Click Expand
4. Check all the _read_ boxes
5. Create deploy token

```sh
kubectl create secret docker-registry <token-name> -n default \
    --docker-username="" \
    --docker-password="" \
    --docker-email="your email for gitlab" \
    --docker-server="registry.gitlab.com"
```
replace \<token-name> with appname-api-token

it should be the same name as line 4 of deploy.yml plus "-token"

ie. likes-api-token

Add username and password from the from the token you just created to the corresponding fields in the shell command.

Be sure to keep the quotes where they are present

**Be sure to add the _appname-deploy.yml_ to the bottom of your _.gitlab-ci.yml_ in the deploy stage!**

**Be sure to add the _appname-api-token_ to your image pull secrets in the _appname-deploy.yml_!**

## Deploy to K8's

* Make sure your are in your root directory of your spring app

```sh
kubectl apply -f appname-deploy.yml
```

If you did not combine both service and deployment in one file make sure to apply your service.yml file
```sh
kubectl apply -f service.yml
```
Run this command
```sh
kubectl get pods -n default
```
Now verify that your pods are running (you may only have one)

```
likes-api-86b55c99b6-pg4vx                  1/1     Running   0          6h6m
```
Now find your service's external ip

```
kubectl get svc
```
```
NAME            TYPE        CLUSTER-IP             EXTERNAL-IP                                                    PORTS      AGE
likes-api-lb LoadBalancer 10.100.50.241 a6d99f2bd58674b9f97114101e99fb28-1194227878.us-west-2.elb.amazonaws.com 80:30946/TCP 6h9m
```
Plug the External IP into postman and test your routes

## Create Routes and Mapping
* This is how we connect our service to the api gateway
* Like the deploy.yml, I am combining two ym's into one
* check this out

Add this file to your root as well

_appname-routes-maps.yml_

```yml
apiVersion: "tanzu.vmware.com/v1"
kind: SpringCloudGatewayRouteConfig
metadata:
  name: appname-api-routes #change me
  namespace: default
spec:
  service: # name of your service
    name: appname-api-lb #change me
    namespace: default
  routes:
    - predicates:
    # your path should start with /api/path
    # plug your route in
        - Path=/api/likes/** # change me
      filters:
        - StripPrefix=0
---
apiVersion: "tanzu.vmware.com/v1"
kind: SpringCloudGatewayMapping
metadata:
  name: appname-api-mapping #change me
  namespace: default
spec:
  gatewayRef:
    name: api-gateway # name of our gatway
    namespace: default
  routeConfigRef:
    name: appname-api-routes #change me
```

Like you did for the deploy apply these files

Make sure you are on root

```sh
kubectl apply -f appname-routes-maps.yml
```

You should see that both files are configured

_routes_
```sh
$: kubectl get scgrc
NAME                  AGE
comments-api-routes   12h
content-api-routes    9h
likes-api-routes      4d12h
ratings-api-routes    6h38m
```
_mapping_
```sh
$: kubectl get scgm
NAME                   AGE
comments-api-mapping   12h
content-api-mapping    9h
likes-api-mapping      4d12h
ratings-api-mapping    6h38m
```

If both are properly configured congrats! it is time to test out the gateway!

We can do this one of two ways

```
$: kubectl get ingress
NAME              CLASS    HOSTS   ADDRESS                                                                   PORTS   AGE
gateway-ingress   <none>   *       acd107acb6ca74a828c1b4399fe3281c-1538335466.us-west-2.elb.amazonaws.com   80      39h
$:
```
To test, just copy and paste this address into postman and try your routes again.

### OR USE OUR NEW DNS

bakery.galvanizelabs.net

ex: bakery.galvanizelabs.net/api/ratings/2

_return from postman..._
```json
{
    "bakerId": 2,
    "averageRating": 5.0
}
```

**REACH OUT IF YOU GET STUCK**

Thanks


