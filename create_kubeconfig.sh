#!/bin/bash
set -eo pipefail

SERVICE_ACCOUNT_NAME="cluster-reader"
CONFIG="kube_config"

create_role() {
    echo -e "\nCreating a service account :: $SERVICE_ACCOUNT_NAME with reader permissions in ${NAMESPACE} namespace \n"
    sed -i "s|@namespace|$NAMESPACE|g" reader-role.yaml 
    kubectl apply -f  ./reader-role.yaml --namespace "${NAMESPACE}"
}

get_secret_name_from_service_account() {
    SECRET_NAME=$(kubectl get sa "${SERVICE_ACCOUNT_NAME}" --namespace="${NAMESPACE}" -o json | jq -r .secrets[].name)
}

extract_cert_from_secret() {
    kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o jsonpath='{.data.ca\.crt}' | base64 -D > "ca.crt"
}

extract_token_from_secret() {
    USER_TOKEN=$(kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o  jsonpath='{.data.token}' | base64 -D)
    echo $USER_TOKEN > reader.token
    echo -e "\nToken written to reader.token file"  
}

create_kubeconfigfile() {

    echo -e "\nCreating Kubeconfig file $CONFIG in current directory\n"

    context=$(kubectl config current-context)
    CLUSTER_NAME=$(kubectl config get-contexts "$context" | awk '{print $3}' | tail -n 1)
    ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")
    
    kubectl config --kubeconfig=$CONFIG set-cluster $CLUSTER_NAME --server=$ENDPOINT --certificate-authority="ca.crt" --embed-certs=true
    kubectl config --kubeconfig=$CONFIG set-credentials $SERVICE_ACCOUNT_NAME-$NAMESPACE-$CLUSTER_NAME --token=$USER_TOKEN
    kubectl config --kubeconfig=$CONFIG set-context $CLUSTER_NAME --cluster=$CLUSTER_NAME --user=$SERVICE_ACCOUNT_NAME-$NAMESPACE-$CLUSTER_NAME
    kubectl config --kubeconfig=$CONFIG use-context $CLUSTER_NAME 
}

echo "Checking if kubectl is present"

if ! hash kubectl 2>/dev/null
then
    echo "'kubectl' was not found in PATH"
    echo "Kindly ensure that you can acces an existing kubernetes cluster via kubectl"
    exit
fi

kubectl version --short

if [[ -z "$1" ]]; then
 echo -e "\nUsage: $0 <namespace> . Defaulting to default namespace , since no namespace was specified"
 NAMESPACE="default"
else
     NAMESPACE="$1"
fi


create_role
get_secret_name_from_service_account
extract_cert_from_secret
extract_token_from_secret
create_kubeconfigfile
