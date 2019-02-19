#!/bin/bash
#az snapshot create -n nome -g rg --sku Standard_LRS --source
#storageProfile.[osDisk.[name,managedDisk.[id]],dataDisks[*].[name,managedDisk.[id]]]
#export STRING_OSDISK=storageProfile.osDisk.[name,managedDisk.id]
#export STRING_DATADISK=storageProfile.dataDisks[*].[name,managedDisk.id]
export STRING_OSDISK=storageProfile.osDisk.managedDisk.id
export STRING_DATADISK=storageProfile.dataDisks[*].managedDisk.id
export SUFIX=$(date +"%Y%m%d%H%M%S")
#Resource Group
export RG=
export VMNAME=
export NEWVMNAME=
#Availability Set, Para não usar comente ou deixe em branco a variável
export AVSET=
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
function GETREGION() {
	# BANNER titulo "Getting region for $1"
	az vm list \
	--query "[?name=='$1'].[location]" \
	-o tsv
}
function LISTDISK() {
  BANNER titulo "List Disks for $VMNAME with string $1"
  az vm show \
    --name $VMNAME \
    -g $RG \
    -d \
    --query "$1" \
    -o tsv > $2
  rc=$? 2>/dev/null
  if [ $rc -ne 0 ]
  then
    EXITNOW "Could not list disks"
  else
    BANNER sucesso "Disks command successful"
  fi
}

function CREATESNAPSHOT() {
	export NDATADISK=$(wc -l $1 | awk '{print $1}')
	if [ $NDATADISK -ne 0 ]
	then
		BANNER titulo "Creating snapshots for $(wc -l $1 | awk '{print $1}') disks"
	  while read  diskid
	  do
	    name=$(echo $diskid | tr '/' '\n' | tail -n 1)
	    BANNER conteudo "Creating snapshot for disk $diskid"
	    echo az snapshot create \
	      -n $VMNAME-so-$SUFIX \
	      -g $RG \
	      --sku Standard_LRS \
	      --source $diskid
	    rc=$? 2>/dev/null
	    if [ $rc -ne 0 ]
	    then
	      EXITNOW "Could not create snapshot for disk $diskid"
	    else
	      BANNER sucesso "Snapshot command successful"
	    fi
	  done < $1
	fi

}

function CREATEDISK() {
	export NDATADISK=$(wc -l $2 | awk '{print $1}')
	if [ $NDATADISK -ne 0 ]
	then
		BANNER titulo "Creating $(wc -l $2  | awk '{print $1}') disks for $1"
	  cat -n $2 | \
	  while read serial snapshot
	  do
	    BANNER conteudo "Creating disk $1-$serial from snapshot $snapshot"
	    az disk create \
	      --name $1-$serial \
	      --resource-group $RG \
	      --location $REGION \
	      --sku Standard_LRS \
	      --source $snapshot
	    rc=$? 2>/dev/null
	    if [ $rc -ne 0 ]
	    then
	      EXITNOW "could not create disk for $1-$serial from snapshot $snapshot"
	    else
	      BANNER sucesso "Disk commando successful"
	    fi
	  done
	fi


}
function CREATEVM() {
	export NDATADISK=$(wc -l $2 | awk '{print $1}')
	if [ $NDATADISK -ne 0 ]
	then
		export DATADISKCREATION=" --attach-data-disks $(seq 1 $(wc -l $2 | awk '{print $1}')|xargs -i echo $NEWVMNAME-{})"
	fi
	export NAVSET=$(echo $AVSET | wc -m)
	if [ $NAVSET -ne 1 ]
	then
		export AVSETCREATION="--availability-set $AVSET"
	fi


	BANNER titulo "Creating Virtual Machine $NEWVMNAME"
	az vm create \
	--name $NEWVMNAME \
	--resource-group $RG \
	--attach-os-disk $NEWVMNAME-os-1 $DATADISKCREATION $AVSETCREATION \
	--subnet $(GETVMDETAIL subnet) \
	--public-ip-address "" \
	--location $REGION \
	--os-type linux \
	--size $(GETVMDETAIL size)
	rc=$? 2>/dev/null
	if [ $rc -ne 0 ]
	then
		EXITNOW "could not create vm $NEWVMNAME"
	else
		BANNER sucesso "Virtual Machine command successful"
	fi

}
function DELETESNAPSHOT() {
  echo dummy
}
function GETVMDETAIL() {
    case $1 in
    size)
      az vm show \
        --name $VMNAME \
        -g $RG \
        -d \
        --query "hardwareProfile.vmSize" \
        -o tsv
      ;;
    subnet)
      az vm nic show --nic \
        $(az vm show \
          --name $VMNAME \
          -g $RG \
          -d \
          --query "networkProfile.networkInterfaces[*].id" \
          -o tsv) \
         -g $RG \
         --vm-name $VMNAME \
         --query "ipConfigurations[*].subnet.id" \
         -o tsv
      ;;
    *)
      echo dummy
      ;;
    esac

}
function STOPVM() {
	BANNER titulo "Stopping Virtual Machine $2"
	sleep 15
	az vm deallocate -n $2 -g $1
	rc=$? 2>/dev/null
	if [ $rc -ne 0 ]
	then
		EXITNOW "could not stop vm $2"
	else
		BANNER sucesso "Virtual Machine STOP successful"
	fi
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
function EXITNOW() {
  BANNER erro "$1"
  exit 1
}
clear
date
export REGION=$(GETREGION $VMNAME)

if [ "$RG" == "" ]
then
  EXITNOW "Variable RG is empty"
fi
if [ "$VMNAME" == "" ]
then
  EXITNOW "Variable VMNAME is empty"
fi
if [ "$NEWVMNAME" == "" ]
then
  EXITNOW "Variable NEWVMNAME is empty"
fi
if [ "$REGION" == "" ]
then
  EXITNOW "Variable REGION is empty"
fi
# echo $REGION
# exit 1
#Create OS Disk
OSDISK=$(TEMPFILE criar)
LISTDISK $STRING_OSDISK  $OSDISK
CREATESNAPSHOT $OSDISK
CREATEDISK $NEWVMNAME-os $OSDISK
#Create Data Disks
DATADISK=$(TEMPFILE criar)
LISTDISK $STRING_DATADISK  $DATADISK
CREATESNAPSHOT $DATADISK
CREATEDISK $NEWVMNAME $DATADISK
CREATEVM $OSDISK $DATADISK
#Apagar arquivos temporarios
TEMPFILE apagar $OSDISK
TEMPFILE apagar $DATADISK
STOPVM $RG $NEWVMNAME
