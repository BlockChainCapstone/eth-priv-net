. ~/bootstrap/eth.config

# Install ethereum
echo ">>  Setting up ethereum"

sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get -y install ethereum

echo ">>  Cleaning up the directory ${BASE_DIR}"
rm -r -f ${BASE_DIR}

echo ">>  Killing geth process"
kill -9 $(ps aux | grep -e "geth" | awk '{ print $2 }')
ps aux | grep -e "geth"


# Creating setup directory and account
echo ">>  Creating base dir"
mkdir ${BASE_DIR}

echo $RANDOM > ${BASE_DIR}/password.txt
geth --datadir ${BASE_DIR}/ account new --password ${BASE_DIR}/password.txt | grep "Public address of the key: "| cut -d: -f2 | cut -dx -f2 |sed 's/^ *//g' > account.txt

