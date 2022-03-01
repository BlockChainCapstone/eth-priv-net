. ~/bootstrap/eth.config

ACCOUNTS=$1
ETHERS=1000

for  ACCOUNT in $(echo "${ACCOUNTS}" | tr ',' '\n'); do
  echo ">> Transferring $ETHERS to account $ACCOUNT"
  EXEC_COMMAND="eth.sendTransaction({from: eth.coinbase, to: '$ACCOUNT',  value: web3.toWei($ETHERS, \"ether\")})"
  echo "Executing geth command : $EXEC_COMMAND"
  geth --exec "${EXEC_COMMAND}" attach ${BASE_DIR}/geth.ipc
done


echo "-----------------------------------------------"
