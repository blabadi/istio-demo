# Demo script (Monitoring And Traffic Management)

To make the best of this demo you should follow through each file in each step here and see what it does and read about the new things you face, you don't have to do it this way if you just want to see things working but it worths the effort as this script helps in providing the plan, but you still have to execute it to gain the benifits.

## Usage
- Microservices code is in ./code, take a look at the different service it should be very straight forward and easy
and also to understand the expected behavoir of the services.

  services hierarchy, in terms of which service calls which.
  ```yaml
    ui: nodeJS
      gateway: nodeJS
        orders: java
          shipping: nodeJS
        users: nodeJS
  ```
- Istio resources under ./istio
  - subdirectories contains resources for different features of istio
- kubernetes resources under ./kube
- Makefile contains bash snippets useful to save typing time

  next is a step by step guide to run this demo.

## Setup
 - start cluster `make kluster`.
    - this uses https://github.com/kubernetes-sigs/kind
    - you can use a managed cluster by google cloud, aws or azure etc, nothing except the GATEWAY_URL in make file will be affected
 - start istio core services `make i-init`.
    this command creates a namespace for istio in k8s then it labels the default namespace for autoinjection
    after that we use helm to create the required custom resources definitions and the yaml files to setup istio services and pods for more information see : https://istio.io/docs/setup/kubernetes/
    note that we enabled some addons like grafana promethus service graph, which are really cool things to get out of the box when you use istio.
    
- show isito services & pods `make k-print`.
you can see istio starting up, if everything goes to status Running then you are good, sometimes things fail to start properly try `make i-init` again it can solve the issue, it happens that some pods take more time and k8s kills them because it thinks they are not alive.

## Deployment 
Now that istio is installed we want deploy our code and start using it, to do that :
- deploy the initial pods & services : `make k-deploy`.
this step deployed our containers on k8s and istio auto injected its proxies in our pods
    - show auto injection (each pod has 2 containers) `watch get pods`
    - istio-proxy `kubectl describe pods frontend` 
      if you want to see what istio added to the pod
- test pods communication `make k-test`.
  this test makes sure our pods are able to reach each others and that k8s dns is able to resolve the urls 
- deploy istio app configs:
    - one by one:
        - `make i-dest-rule`: configures the destination rules per service and the policies per destination / destination subset
        - `make i-routing-1`: configures the front end virtual service that is associated with the gateway
        - `make i-ingress`: deploy the gateway to direct traffic to our front end service 
  
- confirm deployment works: `make demo-frontend`
    - ingress url source
this command will pull based on our cluster the url that the gateway is listening on and does a request where our front end will respond with some minimal html, this means that our app is deployed on the mesh !

## Features:

### Networking 
    - service discovery: our code doesn't have any specific host & port urls, it's all names like this: http://gateway, k8s does the heavy lifting for us here, and istio does the smart routing on top of that
    - routing: istio through virtual services allows alot of flexibility in routing without redploying or code changes at all
    - enforce network polices & security (tbd)

### Monitoring
when we installed istio we configured it with some addons, to make use of them and see them in action you can execute:
`make demo-monitoring`
- Grafana : http://localhost:3000
- Jaeger UI : http://localhost:16686/jaeger/
- promethus : http://localhost:9090/graph
- service graph: http://localhost:8088/dotviz
what this command did, is port forwarding some of our localhost ports to the pods where istio got these services deployed so we can accesss them easily try fiddeling with these and generate some traffic, note that you will need a new terminal tab/window because exiting this command will make them inaccessible.

### Traffic management:
- load balancing:
    istio allows us to define load balancers per destination/destination subset which allows us to distribute load accross replicated instances.
    - see `istio/destinations.yml` => `dr.gateway `
    
- canary deployment: `make ui-v2`
    in this step we will deploy a newer image, tag (2.0.0) of the ui. then we cankssssssssssssssssssssssssssssssssssssssssssssssssssses
    - compare `make demo-frontend` with canary : `make canary-header` 

- gradual rollout: `kubectl apply -f ./istio/ui-v2/routing.weights.yml`
    - v2 at 0%, v1 : 100% .. gradually shift traffic 

- fault injection: `make faulty-shipping`
    - `make gen-traffic`
    - check monitors
    - `make stop-traffic` or ^C
    - remove fault injection: `make rm-faulty-shipping`

- timeout & retry:
    - `make timeout-retry`
    - `make rm-timeout-retry`

- mirroring:
    - `make mirror-frontend`
    - execute requests on frontend
    - check jaeger for shadow requests
    - `make rm-mirror-frontend`

- circuit breaking
    - connection pools
    - outlier detection
    see `./istio/circuit-breaker/shipping-cb.dr.yml`

references:
  - istio doc https://istio.io
  - sample project https://github.com/thesandlord/Istio101
