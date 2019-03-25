
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# only ask if in interactive mode
if [[ -t 0 ]];then
  echo -n "namespace ? [default] "
  read -r NAMESPACE
fi

if [[ -z ${NAMESPACE} ]];then
  NAMESPACE=default
fi

echo "using NAMESPACE=${NAMESPACE}"

protos=( destinationrules virtualservices gateways )
for proto in "${protos[@]}"; do
  for resource in $(kubectl get -n ${NAMESPACE} "$proto" -o name); do
    kubectl delete -n ${NAMESPACE} "$resource";
  done
done

OUTPUT=$(mktemp)
export OUTPUT
echo "Application cleanup may take up to one minute"
kubectl delete -n ${NAMESPACE} -f "$SCRIPTDIR/resources.yml" > "${OUTPUT}" 2>&1
ret=$?
function cleanup() {
  rm -f "${OUTPUT}"
}

trap cleanup EXIT

if [[ ${ret} -eq 0 ]];then
  cat "${OUTPUT}"
else
  # ignore NotFound errors
  OUT2=$(grep -v NotFound "${OUTPUT}")
  if [[ -n ${OUT2} ]];then
    cat "${OUTPUT}"
    exit ${ret}
  fi
fi

echo "Application cleanup successful"