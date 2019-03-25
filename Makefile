ISTIO_VERSION=1.1.0
ISTIO_HOME=~/dev/istio/v$(ISTIO_VERSION)
ISTIO_DIR=istio-$(ISTIO_VERSION)
INGRESS_HOST=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
SECURE_INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
ISTIO_GATEWAY_URL=$(INGRESS_HOST):$(INGRESS_PORT)
# local dev
init:
	cd ./code/ui-app && npm i 
	cd ./code/api-gateway && npm i 
	cd ./code/shipping-svc && npm i 
	cd ./code/users-svc && npm i

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

i-init:
	-kubectl create namespace istio-system
	-kubectl label namespace default istio-injection=enabled --overwrite
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl apply -f -
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio \
	--name istio \
	--namespace istio-system \
	--set global.mtls.enabled=true \
	--set tracing.enabled=true \
	--set servicegraph.enabled=true \
	--set grafana.enabled=true | kubectl apply -f -

# to see the istio generated configs :	
i-gen:
	helm template $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio \
	--name istio --namespace istio-system --set global.mtls.enabled=true --set tracing.enabled=true \
	--set servicegraph.enabled=true --set grafana.enabled=true > istio.yaml	

# provision
k-deploy:
	kubectl apply -f ./kube/resources.yml

k-print:
	kubectl get pods && kubectl get svc && kubectl get svc istio-ingressgateway -n istio-system

k-test:
	kubectl exec -it $(shell kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c frontend -- wget -qO- http://users/ | cat
	kubectl exec -it $(shell kubectl get pod -l app=orders -o jsonpath='{.items[0].metadata.name}') -c orders -- wget -qO- http://shipping/ | cat

i-ingress:
	kubectl apply -f ./istio/ingress.yml
	kubectl get gateway

i-dest-rule:
	kubectl apply -f ./istio/destinations.yml

# demo:
demo-frontend:
	curl -s http://$(ISTIO_GATEWAY_URL)/

# clean up
i-remove:
	-kubectl delete ns istio-system
	-for i in $(ISTIO_HOME)/$(ISTIO_DIR)/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl delete -f $$i; done
	# cleans everything except istio crds (line above)
	echo EXECUTE ./kube/clean.sh To CLEAN UP

# undeploys pods only
k-undeploy:
	kubectl delete -f ./kube/resources.yml