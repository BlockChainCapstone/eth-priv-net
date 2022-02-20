#!/bin/sh -x

export BASEDIR=$(dirname "$0")
export BOOT_NODE_FILE=$1
export SEAL_NODES_FILE=$2
export PEM_FILE=$3

#CONSTS
export ETHER_BOOT="30000000000000000000000000000000"
export USER_ID=ubuntu
export SEAL_ACCTS=""
export ACCT_JSON=""

. ${BASEDIR}/bootstrap/eth.config

SSH_OPTIONS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${PEM_FILE}"

copy_bootstrap(){
	NODE=$1
	echo "Copying the bootstrap script to node $NODE"
	scp ${SSH_OPTIONS} -r ${BASEDIR}/bootstrap/ ${USER_ID}@$NODE:~
}



setup_on_seal_nodes(){
	echo "\n\n\n\n      Setting up Account on Seal Nodes\n"
	while read nodeName; do
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

	done < ${SEAL_NODES_FILE}
}

setup_boot_node(){
	echo "\n\n\n\n              Setting up the boot node\n"
	export BOOT_NODE=`cat $BOOT_NODE_FILE`

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
	while read nodeName; do
                echo "##########################################################"
                echo "Reading Acct  on Node : $nodeName"
                echo "##########################################################"

                ACCT=`ssh ${SSH_OPTIONS} $USER_ID@$nodeName "cat account.txt"`
		ACCT_NOX=`echo $ACCT | cut -dx -f2`
		SEAL_ACCTS="${SEAL_ACCTS}${ACCT_NOX}"
		ACCT_JSON="${ACCT_JSON}\n\\\t\"${ACCT_NOX}\": {\\\n\\\t\\\t\"balance\": \"${ETHER_BOOT}\"\\\n\\\t},"
        done < ${SEAL_NODES_FILE}
	ACCT_JSON=`echo ${ACCT_JSON} |  tail -c +2 | head -c -2`
	
	# Preparing the genesis from genesis.template
	cat genesis.template| sed "s/__ACCOUNT_JSON__/${ACCT_JSON}/g" | sed "s/__SEAL_ACCOUNTS__/${SEAL_ACCTS}/g"  > genesis.json

	echo "Created the genesis file at ${PWD}/genesis.json"
}


start_seal_node(){
	echo "\n\n\n\n           Starting the seal nodes\n"
	 while read nodeName; do
                echo "##########################################################"
                echo " Starting Geth on Seal Node : $nodeName"
                echo "##########################################################"
		
		echo "Copying the genesis file to remote"
		scp ${SSH_OPTIONS} -r ${BASEDIR}/genesis.json ${USER_ID}@$nodeName:~

		echo "Executing the geth process on the node"
		ssh ${SSH_OPTIONS} $USER_ID@$nodeName "sh ~/bootstrap/startNode.sh ${DISCOVERY_ENODE}"
        done < ${SEAL_NODES_FILE}
}

monitor_nodes(){
	echo "\n\n\n\n        Monitoring nodes\n"
	INTERVAL=$1
	while true; do 
		while read nodeName; do
        		echo "\n\n##########################################################"
	                echo " Node : $nodeName"
        	        echo "##########################################################\n\n"

        	        ssh ${SSH_OPTIONS} $USER_ID@$nodeName "tail -10 ~/log.out"
			echo "\n\n##########################################################"
        	done < ${SEAL_NODES_FILE}

		echo "\n\n##########################################################"
                echo " Boot Node : $BOOT_NODE"
                echo "##########################################################\n\n"
                ssh ${SSH_OPTIONS} $USER_ID@${BOOT_NODE} "tail -10 ~/log.out"
                echo "\n\n##########################################################"

		echo "\nSleeeping..............................\n"
		sleep ${INTERVAL}
	done

}

setup_on_seal_nodes

prepare_genesis

setup_boot_node

start_seal_node

monitor_nodes 10
