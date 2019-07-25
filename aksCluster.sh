#!/bin/bash 
export RESOURCEGROUP="rgname"
export CLUSTERNAME="clustername"
export SUBNETID="xxxxxxx"
export SERVICEPRINCIPALID="xxxxxxx"
export SERVICEPRINCIPALSECRET="xxxxxxx"
export TAGS="billing=it"
export VNETNAME="vnnetname"
export SUBNETNAME="subnetname"


function UPGRADE_NODEPOOL() {
  az aks nodepool upgrade \
    --resource-group $RESOURCEGROUP \
    -n $1 \
    --kubernetes-version $2 \
    --cluster-name $CLUSTERNAME
}

function CREATE_AKS() {
  az aks create \
    -n $CLUSTERNAME \
    -g $RESOURCEGROUP \
    -l eastus2 \
    --network-plugin azure \
    --node-count 1 \
    --node-vm-size $1 \
    --node-osdisk-size 127 \
    --nodepool-name default \
    --tags $TAGS \
    --vnet-subnet-id $SUBNETID \
    --service-principal $SERVICEPRINCIPALID \
    --client-secret  $SERVICEPRINCIPALSECRET \
    --enable-vmss \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 10 \
    --node-count 3
    # --network-policy calico
}

function CREATE_NOODEPOOL() {
  az aks nodepool add \
    --resource-group $RESOURCEGROUP \
    --cluster-name $CLUSTERNAME \
    --name $1 \
    --node-vm-size Standard_B4ms  \
    --node-osdisk-size 127 \
    --node-count 2 \
    --vnet-subnet-id $SUBNETID \
    --max-count 10  \
    --min-count 2 \
    --enable-cluster-autoscaler
}
function SCALE_NODEPOOL() {
  az aks nodepool scale \
    --cluster-name $CLUSTERNAME \
    --name $1 \
    --resource-group $RESOURCEGROUP \
    --node-count $2
}
function UPDATE_NODEPOOL_SCALE() {
  az aks nodepool update \
    --cluster-name $CLUSTERNAME \
    --name $1 \
    --resource-group $RESOURCEGROUP \
    --min-count $2 \
    --max-count $3 \
    --update-cluster-autoscaler \
    --enable-cluster-autoscaler
}
function ADD_AZURE_EXTENSIONS() {
  az extension add --name aks-preview
  az feature register --name VMSSPreview --namespace Microsoft.ContainerService
  az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}"
  az provider register --namespace Microsoft.ContainerService
}
function CRASH {
  echo $1
  exit 1
}
function VALIDATE() {
  #Test if resooure group exist
  az group show --name $RESOURCEGROUP 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -ne 0 ]
  then
    CRASH "Resource group do not exist"
  fi
  az aks show  --name $CLUSTERNAME --resource-group $RESOURCEGROUP 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -eq 0 ]
  then
    CRASH "Cluster AKS already exist"
  fi
  # az network vnet list --query "[?name=='$VNETNAME'].[resourceGroup]" -o tsv
  export VNETRG=$(az network vnet list --query "[?name=='$VNETNAME'].[resourceGroup]" -o tsv)
  az network vnet show --name $VNETNAME --resource-group $VNETRG 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -ne 0 ]
  then
    CRASH "VNET does not exist"
  fi
  az network vnet subnet show --vnet-name $VNETNAME --resource-group $VNETRG --name $SUBNETNAME 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -ne 0 ]
  then
    CRASH "SUBNET does not exist"
  fi
}
VALIDATE
ADD_AZURE_EXTENSIONS
CREATE_AKS Standard_B4ms
CREATE_NOODEPOOL small Standard_B4ms
UPGRADE_NODEPOOL small 1.13.7
UPDATE_NODEPOOL_SCALE small 2 20
SCALE_NODEPOOL default 0
