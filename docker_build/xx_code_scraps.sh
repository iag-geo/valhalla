
# 1. build image
#setproxy
cd /Users/$(whoami)/git/iag_geo/valhalla/docker_build
docker build --tag iag-geo/valhalla:3.1.0 .

# 2. deploy image to a Kubernetes pod
kubectl create deployment valhalla --image=iag-geo/valhalla:3.1.0

# scale deployment
kubectl scale deployments/valhalla --replicas=4


# create (i.e. expose) a service
kubectl expose deployment/valhalla --type="NodePort" --port 8002





# check status
kubectl get deployments
kubectl describe deployment
kubectl get pods -l run=valhalla
kubectl get services -l run=valhalla

# change service label (optional)
kubectl label pod $POD_NAME app=valhalla

export NODE_PORT=$(kubectl get services/valhalla -o go-template='{{(index .spec.ports 0).nodePort}}')

# delete service (app is still running inside pod!)
kubectl delete service -l run=kubernetes-bootcamp

# create proxy to access app in pod (NOT required if service is created i.e. exposed)
kubectl proxy

curl http://localhost:8001/version

kubectl get pods -o go-template --template '{{range .items}}{{.mtadata.name}}{{"\n"}}{{end}}'



kubectl logs

# create Bash session inside pod
kubectl exec -ti $POD_NAME bash


## 2. run container
#docker run --name=valhalla --publish=8002:8002 iag-geo/valhalla:3.1.0

# 3. test a URL
curl http://localhost:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'
