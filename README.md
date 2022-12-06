# gitops-sample-stamp
Gitopos Repo for establishing a multi-tenancy environment.

## Prerequisites
Testing this repo leverages azure arc features and requires the following to be enabled:

```bash
# Azure CLI Login
az login
az account set --subscription <your_subscription>

# Add CLI Extensions
az extension add --name connectedk8s

# Update CLI Extensions
az extension update --name connectedk8s
```

## Setup and Testing

To make things easy for the purpose of simple validations a `kind` kubernetes cluster is used and ARC enabled to leverage the native Gitops Configuration functionality.

**Technical Links**

[Kubernetes-sigs/kind](https://github.com/kubernetes-sigs/kind)

[KinD like AKS](https://www.danielstechblog.io/local-kubernetes-setup-with-kind/)

```bash
# Using kind create a Kubernetes Cluster
CLUSTER_NAME="cluster"
kind create cluster --name $CLUSTER_NAME

# Create a Resource Group
RESOURCE_GROUP="sample-stamp"
LOCATION="eastus"
az group create -n $RESOURCE_GROUP -l $LOCATION

# Arc enable the Kubernetes Cluster
az connectedk8s connect -n $CLUSTER_NAME -g $RESOURCE_GROUP

# Configure Flux Extension
az k8s-extension create --name flux --extension-type microsoft.flux --configuration-settings multiTenancy.enforce=false \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME --cluster-type connectedClusters

# Deploy Sample Stamp
az k8s-configuration flux create --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME --cluster-type connectedClusters \
    --name sample-stamp --scope cluster --namespace flux-system \
    --kind git --url https://github.com/danielscholl/gitops-sample-stamp \
    --branch main --kustomization name=config path=./clusters/sample-stamp


# Authorize Azure AD User
CLUSTER_ID=$(az connectedk8s show -n $CLUSTER_NAME -g $RESOURCE_GROUP --query id -o tsv)
AZURE_USER=$(az ad signed-in-user show --query id -o tsv)
kubectl config use-context "kind-$CLUSTER_NAME"
kubectl create clusterrolebinding portal-user-binding --clusterrole cluster-admin --user=$AZURE_USER

az role assignment create --role "Azure Arc Kubernetes Viewer" --assignee $AZURE_USER --scope $CLUSTER_ID
az role assignment create --role "Azure Arc Enabled Kubernetes Cluster User Role" --assignee $AZURE_USER --scope $CLUSTER_ID


# Get a Token for user in Portal (Optional)
kubectl create serviceaccount azure-user
kubectl create clusterrolebinding azure-user-binding --clusterrole cluster-admin --serviceaccount default:azure-user
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: azure-user-secret
  annotations:
    kubernetes.io/service-account.name: azure-user
type: kubernetes.io/service-account-token
EOF

TOKEN=$(kubectl get secret azure-user-secret -o jsonpath='{$.data.token}' | base64 -d | sed 's/$/\n/g')
echo $TOKEN
```
