#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR=`dirname $SCRIPT_DIR`

if [ -z $AZURE_LOCATION ]; then
  AZURE_LOCATION="southcentralus"
fi

# Retrieve Resource Group Name
if [ -z $RESOURCE_GROUP_NAME ]; then
  RESOURCE_GROUP_NAME="gitops-sample-stamp"
fi

if [ -z $CLUSTER_NAME ]; then
  CLUSTER_NAME="sample-cluster"
fi


###############################
## FUNCTIONS                 ##
###############################


function PrintMessage(){
  # Required Argument $1 = Message
  if [ ! -z "$1" ]; then
    echo "    $1"
  fi
}

function Verify(){
    # Required Argument $1 = Value to check
    # Required Argument $2 = Value description for error

    if [ -z "$1" ]; then
      echo "$2 is required and was not provided"
      exit 1
    fi
}

function CreateResourceGroup() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = LOCATION

  Verify $1 'CreateResourceGroup-ERROR: Argument (RESOURCE_GROUP) not received'
  Verify $2 'CreateResourceGroup-ERROR: Argument (LOCATION) not received'

  local _result=$(az group show --name $1 2>/dev/null)
  if [ "$_result"  == "" ]
    then
      az group create --name $1 \
        --location $2 \
        --tags CONTACT=$AZURE_USER \
        -o none
      PrintMessage "  Resource Group Created."
    else
      PrintMessage "  Resource Group: $1 --> Already exists."
    fi
}

function CreateKindCluster() {
  # Required Argument $1 = CLUSTER_NAME

  Verify $1 'CreateKindCluster-ERROR: Argument (CLUSTER_NAME) not received'

  local _result=$(kind get clusters |grep $1 2>/dev/null)
  if [ "$_result"  == "" ]
    then
      cat <<EOF | kind create cluster --name $1 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
      PrintMessage "  Kind Cluster Created."
    else
      PrintMessage "  Kind Cluster: $1 --> Already exists."
    fi
}

function ArcEnableCluster() {
  # Required Argument $1 = CLUSTER_NAME
  # Required Argument $2 = RESOURCE_GROUP

  Verify $1 'CreateKindCluster-ERROR: Argument (CLUSTER_NAME) not received'
  Verify $2 'CreateResourceGroup-ERROR: Argument (RESOURCE_GROUP) not received'

  local _result=$(az connectedk8s show --name $1 --resource-group $2 2>/dev/null)

  if [ "$_result"  == "" ]
    then
      az connectedk8s connect --name $1 --resource-group $2 -o none
      PrintMessage "  Kubernetes Cluster Connected."
    else
      PrintMessage "  Kubernetes Cluster: $1 --> Already connected."
    fi
}

function InstallFlux() {
  # Required Argument $1 = CLUSTER_NAME
  # Required Argument $2 = RESOURCE_GROUP

  Verify $1 'KindCluster-ERROR: Argument (CLUSTER_NAME) not received'
  Verify $2 'CreateResourceGroup-ERROR: Argument (RESOURCE_GROUP) not received'

  local _result=$(az k8s-extension show --name flux --cluster-name $1 --cluster-type connectedClusters --resource-group $2 2>/dev/null)
  if [ "$_result"  == "" ]
    then
      az k8s-extension create --name flux --extension-type microsoft.flux --configuration-settings multiTenancy.enforce=false \
        --cluster-name $1 --cluster-type connectedClusters \
        --resource-group $2 -o none
      PrintMessage "  Flux Extension Installed."
    else
      PrintMessage "  Flux Extension: --> Already installed."
    fi
}

function LoadStamp() {
  # Required Argument $1 = CLUSTER_NAME
  # Required Argument $2 = RESOURCE_GROUP

  Verify $1 'KindCluster-ERROR: Argument (CLUSTER_NAME) not received'
  Verify $2 'CreateResourceGroup-ERROR: Argument (RESOURCE_GROUP) not received'

  local _result=$(az k8s-configuration flux show --name sample-stamp --cluster-name $1 --cluster-type connectedClusters  --resource-group $2 2>/dev/null)
  if [ "$_result"  == "" ]
    then
      az k8s-configuration flux create --resource-group $2 \
        --cluster-name $1 --cluster-type connectedClusters \
        --name sample-stamp --scope cluster --namespace flux-system \
        --kind git --url https://github.com/danielscholl/gitops-sample-stamp \
        --branch main --kustomization name=config path=./clusters/sample-stamp -o none
      PrintMessage "  Gitops Configuration loaded."
    else
      PrintMessage "  Gitops Configuration: --> Already applied."
    fi
}


###############################
## Execution                 ##
###############################

printf "\n"
echo "=================================================================="
echo "Local Deployment"
echo "=================================================================="

PrintMessage "Create Resource Group: $RESOURCE_GROUP_NAME"
CreateResourceGroup $RESOURCE_GROUP_NAME $AZURE_LOCATION

PrintMessage "Create Kind Cluster: $CLUSTER_NAME"
CreateKindCluster $CLUSTER_NAME

PrintMessage "ARC enable Cluster: $CLUSTER_NAME"
ArcEnableCluster $CLUSTER_NAME $RESOURCE_GROUP_NAME

PrintMessage "Install Flux: $CLUSTER_NAME"
InstallFlux $CLUSTER_NAME $RESOURCE_GROUP_NAME

PrintMessage "Load Stamp: $CLUSTER_NAME"
LoadStamp  $CLUSTER_NAME $RESOURCE_GROUP_NAME
