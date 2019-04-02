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
    - one by one:
        - `make i-dest-rule`
        - `make i-routing-1`
        - `make i-ingress`
- confirm deployment works: `make demo-frontend`
    - ingress url source

## features:

### monitoring
`make demo-monitoring`
- Grafana : http://localhost:3000
- Jaeger UI : http://localhost:16686/jaeger/
- promethus : http://localhost:9090/graph
- service graph: http://localhost:8088/dotviz

### traffic management:
- canary deployment: `make ui-v2`
    - compare `make demo-frontend` with canary : `make canary-header` 

- gradual rollout: `kubectl apply -f ./istio/ui-v2/routing.weights.yml`
    - v2 at 0%, v1 : 100% .. gradually shift traffic 

- fault injection: `make faulty-shipping`
    - `make gen-traffic &`
    - check monitors
    - `make stop-traffic`

