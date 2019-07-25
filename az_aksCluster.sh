#!/bin/bash
export RESOURCEGROUP=""
export CLUSTERNAME=""
export SUBNETID=""
export SERVICEPRINCIPALID=""
export SERVICEPRINCIPALSECRET=""
export TAGS=""
export VNETNAME=""
export SUBNETNAME=""


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
function TEMPFILE() {
	case $1 in
	criar)
		mktemp -p /tmp --suffix azure
		;;
	apagar)
		rm  -f $2
		;;
	*)
		EXITNOW "could not create temporary file"
		;;
	esac
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
function EXITNOW() {
  BANNER erro "$1"
  exit 1
}
function BANNER() {
  case $1 in
    titulo)
        echo -e "\e[45m"
        echo $(date +"%Y-%m-%d_%H-%M_%S")\;$2
        echo -en "\e[0m"
        ;;
    conteudo)
        echo -e "\e[44m"
        echo $(date +"%Y-%m-%d_%H-%M_%S")\;$2
        echo -en "\e[0m"
        ;;
    sucesso)
        echo -e "\e[42m"
        echo $(date +"%Y-%m-%d_%H-%M_%S")\;$2
      	echo -en "\e[0m"
        ;;
    erro)
        echo -e "\e[41m"
        echo $(date +"%Y-%m-%d_%H-%M_%S")\;$2
        echo -en "\e[0m"
				exit 1
        ;;
    *)
        EXITNOW
        ;;
  esac

}
function VALIDADE() {
  if [ "$RESOURCEGROUP" == "" ]
  then
    EXITNOW "Variable RESOURCEGROUP is empty"
  fi
  if [ "$CLUSTERNAME" == "" ]
  then
    EXITNOW "Variable CLUSTERNAME is empty"
  fi
  if [ "$SUBNETID" == "" ]
  then
    EXITNOW "Variable SUBNETID is empty"
  fi
  if [ "$SERVICEPRINCIPALID" == "" ]
  then
    EXITNOW "Variable SERVICEPRINCIPALID is empty"
  fi
  if [ "$SERVICEPRINCIPALSECRET" == "" ]
  then
    EXITNOW "Variable SERVICEPRINCIPALSECRET is empty"
  fi
  if [ "$TAGS" == "" ]
  then
    EXITNOW "Variable TAGS is empty"
  fi
  if [ "$VNETNAME" == "" ]
  then
    EXITNOW "Variable VNETNAME is empty"
  fi
  if [ "$SUBNETNAME" == "" ]
  then
    EXITNOW "Variable SUBNETNAME is empty"
  fi
  #Test if resooure group exist
  az group show --name $RESOURCEGROUP 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -ne 0 ]
  then
    EXITNOW "Resource group do not exist"
  fi
  az aks show  --name $CLUSTERNAME --resource-group $RESOURCEGROUP 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -eq 0 ]
  then
    EXITNOW "Cluster AKS already exist"
  fi
  # az network vnet list --query "[?name=='$VNETNAME'].[resourceGroup]" -o tsv
  export VNETRG=$(az network vnet list --query "[?name=='$VNETNAME'].[resourceGroup]" -o tsv)
  az network vnet show --name $VNETNAME --resource-group $VNETRG 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -ne 0 ]
  then
    EXITNOW "VNET does not exist"
  fi
  az network vnet subnet show --vnet-name $VNETNAME --resource-group $VNETRG --name $SUBNETNAME 2>&1 > /dev/null
  RETURN=$?
  if [ $RETURN -ne 0 ]
  then
    EXITNOW "SUBNET does not exist"
  fi
}
VALIDADE
ADD_AZURE_EXTENSIONS
CREATE_AKS Standard_B4ms
CREATE_NOODEPOOL small Standard_B4ms
UPGRADE_NODEPOOL small 1.13.7
UPDATE_NODEPOOL_SCALE small 2 20
SCALE_NODEPOOL default 0
