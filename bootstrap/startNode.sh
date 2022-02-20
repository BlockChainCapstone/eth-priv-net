. ~/bootstrap/eth.config
BN=$1

echo ">>  Initing the genesis.json"
geth --datadir ${BASE_DIR} init genesis.json


echo ">>  Starting the node"
ACCOUNT=`cat account.txt`

nohup geth --datadir=${BASE_DIR} \
--syncmode 'full' \
--port ${GETH_PORT} \
--http \
--http.addr '0.0.0.0' \
--http.port ${HTTP_PORT} \
--http.api admin,eth,miner,net,txpool,personal,web3 \
--bootnodes $BN \
--http.corsdomain '*' \
--networkid ${NETWORK_ID} \
--allow-insecure-unlock \
--unlock "$ACCOUNT" \
--password ${BASE_DIR}/password.txt > ~/log.out 2>&1  &

sleep 2
echo ">> Log "
tail -20 log.out
echo "-----------------------------------------------"

