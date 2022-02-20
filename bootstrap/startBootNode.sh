# Install ethereum
. ~/bootstrap/eth.config

echo ">>  Setting up ethereum"
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get -y install ethereum

echo ">>  killing bootnode process"
kill -9 $(ps aux | grep -e "bootnode" | awk '{ print $2 }')
ps aux | grep -e "bootnode"

echo ">> creating bootnode key"
bootnode --genkey bootnode.key

echo ">> starting bootnode"
nohup bootnode --nodekey bootnode.key --verbosity 9 --addr 0.0.0.0:${BOOT_PORT} > log.out &
