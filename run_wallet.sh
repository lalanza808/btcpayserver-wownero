#!/bin/bash


export DAEMON_URI="${1}"
export WALLET_FILE="/wallet/wallet"
export PASSWORD_FILE="/wallet/password"
export INIT_LOG="/wallet/init.log"

if [[ ! -f ${WALLET_FILE} ]]; then
  echo -e "[!] Wallet file does not exist. Create a new wallet and upload the private view keys to BTCPayServer"
  sleep 10
  exit 1
fi

wownero-wallet-rpc \
  --daemon-address ${DAEMON_URI} \
  --wallet-file ${WALLET_FILE} \
  --password-file ${PASSWORD_FILE} \
  --disable-rpc-login \
  --rpc-bind-port 8000 \
  --rpc-bind-ip 0.0.0.0 \
  --confirm-external-bind \
  --log-file ${WALLET_FILE}.rpc.log \
  --log-level 0 \
  --non-interactive \
  --trusted-daemon \
  --tx-notify="/usr/bin/curl -s -X GET http://btcpayserver:49392/wownerolikedaemoncallback/tx?cryptoCode=wow&hash=%s"

sleep 5