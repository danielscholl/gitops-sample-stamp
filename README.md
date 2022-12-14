# gitops-sample-stamp
[![build](https://github.com/danielscholl/gitops-sample-stamp/actions/workflows/build.yaml/badge.svg)](https://github.com/danielscholl/gitops-sample-stamp/actions/workflows/build.yaml)
[![test](https://github.com/danielscholl/gitops-sample-stamp/actions/workflows/test.yaml/badge.svg)](https://github.com/danielscholl/gitops-sample-stamp/actions/workflows/test.yaml)

This repository serves as a sample for managing a multi-tenant clusters with Git and Flux v2 and is based on samples from [flux2-multi-tenancy](https://github.com/fluxcd/flux2-multi-tenancy).

## Scenario
This sample has a single cluster called `sample-stamp` with a multi-tenant pattern for 1 application [gitops-sample-app](https://github.com/danielscholl/gitops-sample-app)


## Prerequisites

A dev container is present in the repo which makes development and testing easier using an ARC enabled KinD cluster.

The following az extensions are required to run the deployment and are available in the Development Container

- [connectedk8s](https://learn.microsoft.com/en-us/cli/azure/connectedk8s?view=azure-cli-latest)
- [k8s-extension](https://learn.microsoft.com/en-us/cli/azure/k8s-extension?view=azure-cli-latest)
- [k8s-configuration](https://learn.microsoft.com/en-us/cli/azure/k8s-configuration?view=azure-cli-latest)


## Setup and Testing

To make things easy for the purpose of simple validations a `kind` kubernetes cluster is used and ARC enabled to leverage the native Gitops Configuration functionality.

**Technical Links**

[Kubernetes-sigs/kind](https://github.com/kubernetes-sigs/kind)

[KinD like AKS](https://www.danielstechblog.io/local-kubernetes-setup-with-kind/)

```bash
# Azure CLI Login
az login
az account set --subscription <your_subscription>

# Deploy the solution
./_scripts/deploy.sh
```


Workloads can be viewed from within the Azure Portal by leveraging the ARC workload capability.

```bash
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

## Pipelines

Two CI workflows are leveraged in this repo to test the software configuration.

__Build__

Whenever a pull request or merge to main is submitted the Build action is run. This action performs a validation on the format of the yaml using `yq` as well as validating the kubernetes manifests using `kubeconform`.

This validation step can also be run manually with the script `_scripts/validate.sh`.


__Test__

Whenever a pull request or merge to main is submitted the Test action is run. This action performs an end to end integration testing using a KinD cluster as part of the pipeline.  The validation step will ensure that the kustomizations are reconciled successfully.
