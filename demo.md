# Demo script

## setup
 - start cluster `make kluster`
 - start istio core services `make i-init`
    - show isito services & pods `make k-print`

## deployment 
- deploy the initial pods & services : `make k-deploy`
    - show auto injection (each pod has 2 containers)
    - istio-proxy `kubectl describe pods frontend`
- test pods communication `make k-test`
- deploy istio app configs:
    - `make i-deploy-initial`
    - Or one by one:
        - `make i-dest-rule`
        - `make i-routing-1`
        - `make i-ingress`
- confirm deployment works: `make demo-frontend`
    - ingress url source

## features:
- Grafana `make demo-grafana`
