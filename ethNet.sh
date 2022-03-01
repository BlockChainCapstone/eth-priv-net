#!/bin/sh -x

export BASEDIR=$(dirname "$0")
while getopts r:m: flag
do
    case "${flag}" in
        r) RUN_CONFIG=${OPTARG};;
        m) MODE=${OPTARG};;
    esac
done

#CONSTS
export ETHER_BOOT="30000000000000000000000000000000"
export USER_ID=ubuntu
export SEAL_ACCTS=""
export ACCT_JSON=""



checkVar(){
    if [ -z "$1" ]; then
	    echo "Variable $2 cannot be empty"
	    exit 1
    fi
    echo "$2=$1"
}


. ${RUN_CONFIG}
. ${BASEDIR}/bootstrap/eth.config



checkVar $PEM_FILE "PEM_FILE"
checkVar $SEAL_NODES "SEAL_NODES"
checkVar $BOOT_NODE "BOOT_NODE"


SSH_OPTIONS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${PEM_FILE}"


copy_bootstrap(){
	NODE=$1
	echo "Copying the bootstrap script to node $NODE"
	scp ${SSH_OPTIONS} -r ${BASEDIR}/bootstrap/ ${USER_ID}@$NODE:~
}



setup_on_seal_nodes(){
	echo "\n\n\n\n      Setting up Account on Seal Nodes\n"
	for nodeName in $(echo "${SEAL_NODES}" | tr ',' '\n'); do
		echo "##########################################################"
		echo "Setting up on Node : $nodeName"
		echo "##########################################################"

		echo "Copying the bootstrap on $nodeName"
		copy_bootstrap $nodeName

		echo "Create sealer account on $nodeName"
		ssh ${SSH_OPTIONS} $USER_ID@$nodeName "sh ~/bootstrap/setupSealAccount.sh"
		
		ACCT=`ssh ${SSH_OPTIONS} $USER_ID@$nodeName "cat account.txt"`

		echo "##########################################################"
		echo "   Seal Account created -  $ACCT"
		echo "##########################################################"

	done 
}

setup_boot_node(){
	echo "\n\n\n\n              Setting up the boot node\n"

	echo "##########################################################"
	echo "Starting Boot node on ${BOOT_NODE}"
	echo "##########################################################"
	copy_bootstrap ${BOOT_NODE} 

	ssh ${SSH_OPTIONS} $USER_ID@${BOOT_NODE} "sh ~/bootstrap/startBootNode.sh"
	BOOT_ENODE=`ssh ${SSH_OPTIONS} $USER_ID@${BOOT_NODE} "cat ~/log.out | grep enode| cut -d@ -f1"`
	
	export DISCOVERY_ENODE="${BOOT_ENODE}@${BOOT_NODE}:${BOOT_PORT}"
	echo "##########################################################"
	echo "Boot node start with  enode : ${DISCOVERY_ENODE}"
	echo "##########################################################"
}


prepare_genesis(){
	echo "\n\n\n\n        Preparing the genesis\n"
	# Getting the acct details
	for  nodeName in $(echo "${SEAL_NODES}" | tr ',' '\n'); do
                echo "##########################################################"
                echo "Reading Acct  on Node : $nodeName"
                echo "##########################################################"

                ACCT=`ssh ${SSH_OPTIONS} $USER_ID@$nodeName "cat account.txt"`
		ACCT_NOX=`echo $ACCT | cut -dx -f2`
		SEAL_ACCTS="${SEAL_ACCTS}${ACCT_NOX}"
		ACCT_JSON="${ACCT_JSON}\\\n\\\t\"${ACCT_NOX}\": {\\\n\\\t\\\t\"balance\": \"${ETHER_BOOT}\"\\\n\\\t},"
        done 
	ACCT_JSON=`echo ${ACCT_JSON} |  head -c -2`
	# Preparing the genesis from genesis.template
	cat genesis.template| sed "s/__ACCOUNT_JSON__/${ACCT_JSON}/g" | sed "s/__SEAL_ACCOUNTS__/${SEAL_ACCTS}/g"  > genesis.json

	echo "Created the genesis file at ${PWD}/genesis.json"
}


start_seal_node(){
	echo "\n\n\n\n           Starting the seal nodes\n"
	 for nodeName in $(echo "${SEAL_NODES}" | tr ',' '\n'); do
                echo "##########################################################"
                echo " Starting Geth on Seal Node : $nodeName"
                echo "##########################################################"
		
		echo "Copying the genesis file to remote"
		scp ${SSH_OPTIONS} -r ${BASEDIR}/genesis.json ${USER_ID}@$nodeName:~

		echo "Executing the geth process on the node"
		ssh ${SSH_OPTIONS} $USER_ID@$nodeName "sh ~/bootstrap/startNode.sh ${DISCOVERY_ENODE}"
        done 
}

monitor_nodes(){
	echo "\n\n\n\n        Monitoring nodes\n"
	INTERVAL=$1
	COUNT=10
	while [ "$COUNT" -ge "0" ]; do 
		for  nodeName in $(echo "${SEAL_NODES}" | tr ',' '\n'); do
        		echo "\n\n##########################################################"
	                echo " Node : $nodeName"
        	        echo "##########################################################\n\n"

        	        ssh ${SSH_OPTIONS} $USER_ID@$nodeName "tail -10 ~/log.out"
			echo "\n\n##########################################################"
        	done 

		echo "\n\n##########################################################"
                echo " Boot Node : $BOOT_NODE"
                echo "##########################################################\n\n"
                ssh ${SSH_OPTIONS} $USER_ID@${BOOT_NODE} "tail -10 ~/log.out"
                echo "\n\n##########################################################"

		echo "\nSleeeping..............................\n"
		sleep ${INTERVAL}

		COUNT=$((COUNT-1))
	done

}


case "${MODE}" in
        setup) 
		setup_on_seal_nodes

		prepare_genesis

		setup_boot_node

		start_seal_node
	;;

        monitor) 
		monitor_nodes 10	
	;;
esac
