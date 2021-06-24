# fill out values
# double check namespace
kubectl create secret docker-registry <token-name> -n default \
    --docker-username="" \
    --docker-password="" \
    --docker-email="" \
    --docker-server="registry.gitlab.com"