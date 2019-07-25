#!/bin/bash
#echo $* > /tmp/data
#exit 0
function GETNIC(){
  az vm nic show --nic $1 --vm-name $2 --resource-group $3 --query "[ipConfigurations[0].privateIpAddress]" -o tsv
}
function GETVMNIC(){
  az vm show  --ids $1 --query "[networkProfile.networkInterfaces[0].[id,resourceGroup]]" -o tsv
}
function GETVMNICBYTAG() {
  PATTERN=$1
  TAG=$(echo $PATTERN | awk -F _ '{print $1}')
  VALUE=$(echo $PATTERN | awk -F _ '{print $2}')
  az vm list --query "[].[tags.$TAG=='$VALUE',id,name]" -o tsv | \
  while read STATUS ID NAME
  do
    if [ "$STATUS" == "True" ]
    then
      #echo $ID
      GETVMNIC $ID | \
      while read NIC NICRG
      do
        echo $(GETNIC $NIC $NAME $NICRG) $NAME $(az vm show --ids $ID --query "[hardwareProfile.vmSize,location,resourceGroup]" -o tsv )
      done
    fi
  done
}
function GETVMNICBYNAME() {
  az vm list --query "[].[id,name]" -o tsv |  \
  while read ID NAME
  do
    export RC=$(echo $(echo $NAME | tr '[A-Z]' '[a-z]') | grep -i  $1 | wc -l)
    if [ $RC -eq 1 ]
    then
      GETVMNIC $ID  | \
      while read NIC NICRG
      do
        echo $(GETNIC $NIC $NAME $NICRG) $NAME $(az vm show --ids $ID --query "[hardwareProfile.vmSize,location,resourceGroup]" -o tsv )
      done
    fi
  done
}
function GETVMNICBYRG() {
  az vm list --query "[].[id,name,resourceGroup]" -o tsv |  \
  while read ID NAME RG
  do
    export RC=$(echo $(echo $RG | tr '[A-Z]' '[a-z]') | grep -iw  $1 | wc -l)
    if [ $RC -eq 1 ]
    then
      GETVMNIC $ID  | \
      while read NIC NICRG
      do
        echo $(GETNIC $NIC $NAME $NICRG) $NAME $(az vm show --ids $ID --query "[hardwareProfile.vmSize,location,resourceGroup]" -o tsv )
      done
    fi
  done
}
function GETVMIDBYNAME() {
  az vm list --query "[].[id,name]" -o tsv |  \
  while read ID NAME
  do
    export RC=$(echo $(echo $NAME | tr '[A-Z]' '[a-z]') | grep -i  $1 | wc -l)
    if [ $RC -eq 1 ]
    then
      echo $ID
    fi
  done
}
function GETVMIDBYRG() {
  az vm list --query "[].[id,name,resourceGroup]" -o tsv | grep -wi $1 | \
  while read ID NAME RG
  do
    export RC=$(echo $(echo $RG | tr '[A-Z]' '[a-z]') | grep -iw  $1 | wc -l)
    if [ $RC -eq 1 ]
    then
      echo $ID
    fi
  done
}
function GETVMIDBYTAG() {
  PATTERN=$1
  TAG=$(echo $PATTERN | awk -F _ '{print $1}')
  VALUE=$(echo $PATTERN | awk -F _ '{print $2}')
  az vm list --query "[].[tags.$TAG=='$VALUE',id,name]" -o tsv | \
  while read STATUS ID NAME
  do
    if [ "$STATUS" == "True" ]
    then
      echo $ID
    fi
  done
}
function HELP() {
  BINNAME=$(echo $0 | tr '\/' '\n' | tail -n 1)
  echo HELP
  echo Exemplos:
  echo $BINNAME nic tag role_maprprd
  echo $BINNAME nic name mapr
  echo $BINNAME nic rg RG-BIGDATA
  echo $BINNAME id name mapr
  echo $BINNAME id tag mapr
  echo $BINNAME id rg RG-BIGDATA
}
if [ $# -ne 3 ]
then
  HELP
  exit 1
else
  export KEY=$(echo $1 | tr '[A-Z]' '[a-z]')
  export KEY2=$(echo $2 | tr '[A-Z]' '[a-z]')
  case $KEY in
     nic )
      case $KEY2 in
        tag )
          GETVMNICBYTAG $3
          ;;
        name )
          GETVMNICBYNAME $(echo $3 | tr '[A-Z]' '[a-z]')
          ;;
        rg )
          GETVMNICBYRG $(echo $3 | tr '[A-Z]' '[a-z]')
          ;;
        * )
          HELP
          ;;
      esac
      ;;
     id )
      case $KEY2 in
        name )
          GETVMIDBYNAME $(echo $3 | tr '[A-Z]' '[a-z]')
          ;;
        tag )
          GETVMIDBYTAG $3
          ;;
        rg )
          GETVMIDBYRG $(echo $3 | tr '[A-Z]' '[a-z]')
          ;;
      esac
      ;;
     * )
      HELP
      ;;
  esac
fi
