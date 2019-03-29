ISTIO_VERSION=1.1.0
ISTIO_HOME=~/dev/istio/v$(ISTIO_VERSION)
ISTIO_DIR=istio-$(ISTIO_VERSION)
INGRESS_HOST=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
SECURE_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
ISTIO_GATEWAY_URL=$(INGRESS_HOST):$(INGRESS_PORT)
CTX_NAMESPACE=default

ZIPKIN_POD_NAME=$(shell kubectl -n istio-system get pod -l app=zipkin -o jsonpath='{.items[0].metadata.name}')
JAEGER_POD_NAME=$(shell kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{.items[0].metadata.name}')
SERVICEGRAPH_POD_NAME=$(shell kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}')
GRAFANA_POD_NAME=$(shell kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
PROMETHEUS_POD_NAME=$(shell kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')

# local dev
init:
	cd ./code/ui-app && npm i 
	cd ./code/api-gateway && npm i 
	cd ./code/shipping-svc && npm i 
	cd ./code/users-svc && npm i
	cd ./code/orders-svc && ./mvnw install

run-local:
	GATEWAY_URL=http://localhost:3003 nohup node ./code/ui-app/index.js &
	USER_URL=http://localhost:3001 ORDER_URL=http://localhost:3002 nohup node ./code/api-gateway/index.js &
	nohup node ./code/users-svc/index.js &
	nohup node ./code/shipping-svc/index.js &
	cd ./code/orders-svc && ./mvnw spring-boot:run -DSHIPPING_URL=http://localhost:3005

stop-local:
	killall node

# builds & artifacts
d-build:
	docker build -t basharlabadi/istio-demo.frontend:1.0.0 ./code/ui-app
	docker build -t basharlabadi/istio-demo.gateway:1.0.0 ./code/api-gateway
	docker build -t basharlabadi/istio-demo.users:1.0.0 ./code/users-svc
	docker build -t basharlabadi/istio-demo.orders:1.0.0 ./code/orders-svc
	docker build -t basharlabadi/istio-demo.shipping:1.0.0 ./code/shipping-svc	

d-push:
	docker login
	docker push basharlabadi/istio-demo.frontend:1.0.0
	docker push basharlabadi/istio-demo.gateway:1.0.0 
	docker push basharlabadi/istio-demo.users:1.0.0 
	docker push basharlabadi/istio-demo.orders:1.0.0 
	docker push basharlabadi/istio-demo.shipping:1.0.0

# infra	
i-get:
	-mkdir -p $(ISTIO_HOME)
	wget https://github.com/istio/istio/releases/download/$(ISTIO_VERSION)/$(ISTIO_DIR)-linux.tar.gz -O $(ISTIO_HOME)/$(ISTIO_DIR)-linux.tar.gz
	tar -C $(ISTIO_HOME) -zxvf $(ISTIO_HOME)/$(ISTIO_DIR)-linux.tar.gz 

i-init-min:
	-kubectl create namespace istio-system
	-kubectl label namespace default istio-injection=enabled --overwrite
	# the below settings should match or the 2nd command will hang
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio-init \
	--name istio-init \
	--namespace istio-system \
	--set grafana.enabled=true \
	| kubectl apply -f -
	sleep 10
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio \
	--name istio \
	--namespace istio-system \
	--set grafana.enabled=true \
	| kubectl apply -f -
	kubectl get svc -n istio-system
	kubectl get pods -n istio-system

i-init:
	-kubectl create namespace istio-system
	-kubectl label namespace default istio-injection=enabled --overwrite
	# the below settings should match or the 2nd command will hang
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio-init \
	--name istio-init \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true | kubectl apply -f -
	sleep 20
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio \
	--name istio \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true | kubectl apply -f -
	kubectl get svc -n istio-system
	kubectl get pods -n istio-system


# to see the istio generated configs :	
i-gen:
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio-init \
	--name istio-init \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true > ./istio/gen/istio-init.yaml
	sleep 10
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio \
	--name istio \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true > ./istio/gen/istio.yaml	

# provision (needs auto injection for istio to work here)
k-deploy:
	kubectl apply -f ./kube/resources.yml

# if auto injection not working (https://github.com/istio/istio/issues/7266)
i-inject-deploy:
	$(ISTIO_HOME)/$(ISTIO_DIR)/bin/istioctl kube-inject -f ./kube/resources.yml  | kubectl apply -f -

k-ctx:
	kubectl config set-context $(kubectl config current-context) --namespace=$(CTX_NAMESPACE)

k-print:
	-kubectl get pods && kubectl get svc && kubectl get svc istio-ingressgateway -n istio-system
	-kubectl get svc -n istio-system -o wide
	-kubectl get pods -n istio-system -o wide

k-test:
	kubectl exec -it $(shell kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c frontend -- wget -qO- http://users/ | cat
	kubectl exec -it $(shell kubectl get pod -l app=orders -o jsonpath='{.items[0].metadata.name}') -c orders -- wget -qO- http://shipping/ | cat

i-dest-rule:
	kubectl apply -f ./istio/destinations.yml

i-rt-1: i-dest-rule
	kubectl apply -f ./istio/routing.1.yml

i-ingress: 
	kubectl apply -f ./istio/ingress.yml
	kubectl get gateway

# demo:
demo-frontend: # depends on >> i-ingress & i-rt-1
	curl -S http://$(ISTIO_GATEWAY_URL)/

# https://istio.io/docs/tasks/telemetry/metrics/using-istio-dashboard/
demo-grafana:
	echo http://localhost:3000/
	kubectl port-forward -n istio-system $(shell kubectl get pod -n istio-system  -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 

echo-links:
	@echo "service graph: http://localhost:8088/dotviz"
	@echo "tracing: http://localhost:16686"
	@echo "grafana: http://localhost:3000"
	@echo "prometheus http://locahost:9090"
	
demo-monitoring: echo-links
	# $(shell kubectl -n istio-system port-forward $(JAEGER_POD_NAME) 16686:16686 \
	# & kubectl -n istio-system port-forward $(SERVICEGRAPH_POD_NAME) 8088:8088 \
	# & kubectl -n istio-system port-forward $(GRAFANA_POD_NAME) 3000:3000 \
	# & kubectl -n istio-system port-forward $(PROMETHEUS_POD_NAME) 9090:9090)

stop-monitoring:
	killall kubectl

# clean up
i-remove:
	-kubectl delete ns istio-system
	-for i in $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl delete -f $$i; done
	# cleans everything except istio crds (line above)
	echo EXECUTE ./kube/clean.sh To CLEAN UP

i-debug: 
	$(ISTIO_HOME)/$(ISTIO_DIR)/bin/istioctl proxy-status
	# kubectl describe pods -n istio-system
	# kubectl logs pods -n istio-system
	# kubectl describe deployment

# undeploys pods only
k-undeploy:
	kubectl delete -f ./kube/resources.yml