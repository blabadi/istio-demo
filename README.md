# Code Usage

- Microservices code is in ./code
  ```
    ui (node)
    -> gateway (node)
        -> orders (java)
          -> shipping (node)
        -> shipping (node)
  ```

- Istio resources under ./istio
  - ingress: contains the gateway 





---
# Istio

## infrastucture
prerequiset: k8s cluster
## Istio setup
- download https://istio.io/docs/setup/kubernetes/install/kubernetes/
- create profile:
   ```bash
   $ kubectl create namespace istio-system

   # init CRDs
   $ helm template install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl apply -f -

   # install profile
   $ helm template <istio-home>/install/kubernetes/helm/istio --name istio --namespace istio-system --set global.mtls.enabled=true --set tracing.enabled=true --set servicegraph.enabled=true --set grafana.enabled=true > istio.yaml

   $ kubectl apply -f istio.yaml
   ```
   or you can do `helm install`, see: https://istio.io/docs/setup/kubernetes/install/helm/

- deploy istio:
  ```bash
  # create istio mesh
  kubectl apply -f istio.yaml

  #enable auto injection
  kubectl label namespace default istio-injection=enabled --overwrite
  ```

  now istio is ready to be used.

## Using Istio

1- deploy application pods  (platform resources)
  - k8s Deployments(replicaset + pods) + services
  `kubectl apply -f project/k8s/services.yaml`
  `kubectl apply -f project/k8s/deployments.yaml`

2- deploy istio resources (the mesh).

### Traffic management:
  - ingress (gateway):
    - category: traffic management / networking
    - docs: https://istio.io/docs/reference/config/networking/v1alpha3/gateway/
    - contains a Gateway + Virtual service (to route requests to specific apis)
    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: Gateway
    metadata:
      name: my-gateway
    spec:
      selector:
        istio: ingressgateway # use istio default controller
      servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
          - my.host.com
     ---
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: frontend-service
    spec:
      hosts:
      - my.host.com
      gateways:
      - my-gateway
      http:
      - route:
        - destination:
            host: frontend
            port:
              number: 80
    ```
  - destination rules:
    - https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/
    - define all rules that should be applied after a route occured:
      - load balancing
      - connection pooling & circuit breaking
    - label specific policies can be specified (subsets)
    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: DestinationRule
    metadata:
      name: bookinfo-ratings
    spec:
      host: ratings.prod.svc.cluster.local
      # default load balancing policy
      trafficPolicy:
        loadBalancer:
          simple: LEAST_CONN

      # uses a round robin load balancing policy for all traffic going to a
      # subset named testversion that is composed of endpoints (e.g., pods) with
      # labels (version:v3).
      subsets:
      - name: testversion
        labels:
          version: v3
        trafficPolicy:
          loadBalancer:
            simple: ROUND_ROBIN
        ```
  - Virtual services:
    - https://istio.io/docs/reference/config/networking/v1alpha3/virtual-service/
    - manage everything in the context of routing
      - here we can create routing rules and forward traffic to DestinationRules 

    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: reviews-route
    spec:
      hosts:
      - reviews.prod.svc.cluster.local
      http:
      # conditional route
      - match:
        - uri:
            prefix: "/wpcatalog"
        - uri:
            prefix: "/consumercatalog"
        rewrite:
          uri: "/newcatalog"
        route:
        - destination:
            host: reviews.prod.svc.cluster.local
            subset: v2
      # default route:
      - route:
        - destination:
            host: reviews.prod.svc.cluster.local
            subset: v1
    ```

    the corresponding `DestinationRules`:

    ```yaml
    apiVersion: networking.istio.io/v1alpha3
    kind: DestinationRule
    metadata:
      name: reviews-destination
    spec:
      host: reviews.prod.svc.cluster.local
      subsets:
      - name: v1
        labels:
          version: v1
      - name: v2
        labels:
          version: v2
    ```

  - ServiceEntry (egress):
    - https://istio.io/docs/reference/config/networking/v1alpha3/service-entry/
    - used to connect to outside services
    - can be wrapped with DestinationRule so other services make use of istio
    in communications with these services (see docs link for example)
    - example:
    external service
    ```yaml
      apiVersion: networking.istio.io/v1alpha3
        kind: ServiceEntry
        metadata:
          name: jsontime
        spec:
          hosts:
          - worldclockapi.com
          ports:
          - number: 80
            name: http
            protocol: HTTP
          - number: 443
            name: https
            protocol: HTTPS
    ```

others:
  - EnovyFilter https://istio.io/docs/reference/config/networking/v1alpha3/envoy-filter/
  - Sidecar https://istio.io/docs/reference/config/networking/v1alpha3/sidecar/


sample project:
  https://github.com/thesandlord/Istio101

references:
  istio doc + sample project
