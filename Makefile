
K8S_NAMESPACE=default

## Istio installation dir ##
ISTIO_VERSION=1.1.0
ISTIO_HOME=~/dev/istio/v$(ISTIO_VERSION)
ISTIO_DIR=istio-$(ISTIO_VERSION)
ISTIO_DIR_PATH=$(ISTIO_HOME)/$(ISTIO_DIR)

## Ingress Props ##
GATEWAY_TYPE=NODE#, EXT_LB
# these are for clusters with external load balancer (cloud platforms)
EXT_LB_INGRESS_HOST=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
EXT_LB_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
EXT_LB_SECURE_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
EXT_LB_GATEWAY_URL=$(EXT_LB_INGRESS_HOST):$(EXT_LB_INGRESS_PORT)
# these are for direct k8s worker node access 
NODE_INGRESS_HOST=$(shell kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
NODE_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
NODE_SECURE_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
NODE_GATEWAY_URL=$(NODE_INGRESS_HOST):$(NODE_INGRESS_PORT)
# final gateway
ISTIO_GATEWAY_URL=$($(GATEWAY_TYPE)_GATEWAY_URL)


## Monitoring services
# for zipkin see: https://istio.io/docs/tasks/telemetry/distributed-tracing/zipkin/
# ZIPKIN_POD_NAME=$(shell kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{.items[0].metadata.name}')
JAEGER_POD_NAME=$(shell kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{.items[0].metadata.name}')
SERVICEGRAPH_POD_NAME=$(shell kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}')
GRAFANA_POD_NAME=$(shell kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
PROMETHEUS_POD_NAME=$(shell kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')

# CODE ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# d stands for docker
init:
	cd ./code/ui-app && npm i 
	cd ./code/api-gateway && npm i 
	cd ./code/shipping-svc && npm i 
	cd ./code/users-svc && npm i
	cd ./code/orders-svc && ./mvnw install

# (optional to test locally)
run-local:
	GATEWAY_URL=http://localhost:3003 nohup node ./code/ui-app/index.js &
	USER_URL=http://localhost:3001 ORDER_URL=http://localhost:3002 nohup node ./code/api-gateway/index.js &
	nohup node ./code/users-svc/index.js &
	nohup node ./code/shipping-svc/index.js &
	cd ./code/orders-svc && ./mvnw spring-boot:run -DSHIPPING_URL=http://localhost:3005

stop-local:
	killall node

d-build:
	# front end v1 has to be be built manually if needed (use index.1.js, but docker image 1.0.0 exists on docker hub)
	docker build -t basharlabadi/istio-demo.frontend:2.0.0 ./code/ui-app 
	docker build -t basharlabadi/istio-demo.gateway:1.0.0 ./code/api-gateway
	docker build -t basharlabadi/istio-demo.users:1.0.0 ./code/users-svc
	docker build -t basharlabadi/istio-demo.orders:1.0.0 ./code/orders-svc
	docker build -t basharlabadi/istio-demo.shipping:1.0.0 ./code/shipping-svc	

d-push:
	docker login
	docker push basharlabadi/istio-demo.frontend:2.0.0
	docker push basharlabadi/istio-demo.gateway:1.0.0 
	docker push basharlabadi/istio-demo.users:1.0.0 
	docker push basharlabadi/istio-demo.orders:1.0.0 
	docker push basharlabadi/istio-demo.shipping:1.0.0

redploy-all: d-build d-push

step-1: init d-build d-push
	echo "done step 1 (code + artifacts)"


# INFRA -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# i stands for istio, k for kubectl
# download istio (locally to be used by kubectl)
kluster:
	kind create cluster --name=istio-demo --config=./KinD/kind-cluster.yaml
	# export KUBECONFIG="$(kind get kubeconfig-path --name="istio-demo")"
	kubectl cluster-info
	
i-get:
	-mkdir -p $(ISTIO_HOME)
	wget https://github.com/istio/istio/releases/download/$(ISTIO_VERSION)/$(ISTIO_DIR)-linux.tar.gz -O $(ISTIO_HOME)/$(ISTIO_DIR)-linux.tar.gz
	tar -C $(ISTIO_HOME) -zxvf $(ISTIO_HOME)/$(ISTIO_DIR)-linux.tar.gz 

i-init:
	-kubectl create namespace istio-system
	-kubectl label namespace default istio-injection=enabled --overwrite
	# the below settings should match or the 2nd command will hang
	helm template $(ISTIO_DIR_PATH)/install/kubernetes/helm/istio-init \
	--name istio-init \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set pilot.traceSampling=95 \
	--set grafana.enabled=true | kubectl apply -f -
	sleep 20
	helm template $(ISTIO_DIR_PATH)/install/kubernetes/helm/istio \
	--name istio \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set pilot.traceSampling=95 \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true | kubectl apply -f -
	kubectl get svc -n istio-system
	kubectl get pods -n istio-system
	
# (optional) to see the istio generated configs :	
i-gen:
	helm template $(ISTIO_DIR_PATH)/install/kubernetes/helm/istio-init \
	--name istio-init \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true > ./istio/gen/istio-init.yaml
	sleep 10
	helm template $(ISTIO_DIR_PATH)/install/kubernetes/helm/istio \
	--name istio \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true > ./istio/gen/istio.yaml	

# provision (needs auto injection for istio to work here)
# (skip if auto injection disabled and execute: i-inject-deploy)
k-deploy:
	kubectl apply -f ./kube/resources.yml

# if auto injection not working (https://github.com/istio/istio/issues/7266)
i-inject-deploy:
	$(ISTIO_DIR_PATH)/bin/istioctl kube-inject -f ./kube/resources.yml  | kubectl apply -f -

k-print:
	-kubectl get pods && kubectl get svc
	-kubectl get svc -n istio-system -o wide
	-kubectl get pods -n istio-system -o wide

k-test:
	kubectl exec -it $(shell kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c frontend -- wget -qO- http://users/ | cat - && echo ''
	kubectl exec -it $(shell kubectl get pod -l app=orders -o jsonpath='{.items[0].metadata.name}') -c orders -- wget -qO- http://shipping/ | cat - && echo ''

i-dest-rule:
	kubectl apply -f ./istio/destinations.yml

i-routing-1: i-dest-rule
	kubectl apply -f ./istio/routing.1.yml

i-ingress: 
	kubectl apply -f ./istio/ingress.yml
	kubectl get gateway

# this does all the istio steps so far
deploy-initial: k-deploy i-dest-rule i-routing-1 i-ingress


# DEMO -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
demo-frontend: # depends on >> i-ingress & i-routing-1
	curl -sS http://$(ISTIO_GATEWAY_URL)/

# https://istio.io/docs/tasks/telemetry/metrics/using-istio-dashboard/
demo-grafana:
	echo http://localhost:3000/
	kubectl port-forward -n istio-system $(GRAFANA_POD_NAME) 3000:3000 

echo-links:
	@echo "service graph: http://localhost:8088/dotviz"
	@echo "jaeger-ui: http://localhost:16686"
	@echo "grafana: http://localhost:3000"
	@echo "prometheus http://localhost:9090"

demo-monitoring: echo-links
	$(shell kubectl -n istio-system port-forward $(JAEGER_POD_NAME) 16686:16686 \
	& kubectl -n istio-system port-forward $(SERVICEGRAPH_POD_NAME) 8088:8088 \
	& kubectl -n istio-system port-forward $(GRAFANA_POD_NAME) 3000:3000 \
	& kubectl -n istio-system port-forward $(PROMETHEUS_POD_NAME) 9090:9090) 
	

ui-v2:
	kubectl apply -f ./kube/ui-v2/ui-app-v2.yml
	kubectl apply -f ./istio/ui-v2/dest-rule.yml
	kubectl apply -f ./istio/ui-v2/routing.header.yml
	# kubectl apply -f ./istio/ui-v2/routing.weights.yml

canary-header:
	curl -X GET \
        http://$(ISTIO_GATEWAY_URL)/ \
        	-H 'cache-control: no-cache' \
        	-H 'x-end-user: canary-user'

faulty-shipping:
	kubectl apply -f ./istio/fault-injection/shipping-vs.yml

rm-faulty-shipping:
	kubectl delete -f ./istio/fault-injection/shipping-vs.yml

timeout-retry:
	kubectl apply -f ./istio/timeout-retry/shipping-vs.yml
	kubectl apply -f ./istio/timeout-retry/orders-vs.yml

rm-timeout-retry:
	kubectl delete -f ./istio/timeout-retry/shipping-vs.yml
	kubectl delete -f ./istio/timeout-retry/orders-vs.yml

mirror-frontend:
	kubectl apply -f ./kube/ui-v2/ui-app-v2.yml
	kubectl apply -f ./istio/mirroring/dest-rule.yml
	kubectl apply -f ./istio/mirroring/mirror-frontend-v2.yml

rm-mirror-frontend:
	kubectl delete -f ./kube/ui-v2/ui-app-v2.yml
	kubectl delete -f ./istio/mirroring/dest-rule.yml
	kubectl delete -f ./istio/mirroring/mirror-frontend-v2.yml

# if in the background
stop-monitoring:
	killall kubectl

# CLEAN UP --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
i-remove:
	-kubectl delete ns istio-system
	-for i in $(ISTIO_DIR_PATH)/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl delete -f $$i; done
	# cleans everything except istio crds (line above)
	echo EXECUTE ./kube/clean.sh To CLEAN UP

# undeploys pods only
k-undeploy:
	-kubectl delete -f ./kube/resources.yml
	-kubectl delete -f ./kube/ui-v2/ui-app-v2.yml


# EXTRA STUFF -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# various debugging commands:
i-debug: 
	$(ISTIO_DIR_PATH)/bin/istioctl proxy-status
	# kubectl describe pods -n istio-system
	# kubectl logs pods -n istio-system
	# kubectl describe deployment

k-ctx:
	kubectl config set-context $(shell kubectl config current-context) --namespace=$(K8S_NAMESPACE)

k-edit-pilot:
	kubectl -n istio-system edit deploy istio-pilot

redeploy-orders:
	cd ./code/orders-svc && ./mvnw clean install
	docker build -t basharlabadi/istio-demo.orders:1.0.0 ./code/orders-svc
	docker push basharlabadi/istio-demo.orders:1.0.0 
	kubectl delete deployments.apps orders
	make k-deploy

gen-traffic:
	while true; do curl -sS http://$(ISTIO_GATEWAY_URL)/; sleep 0.3; done 

stop-traffic:
	killall make