#!/bin/bash


export WALLET_CREDS="${1}"
export DAEMON_URI="${2}"
export WALLET_FILE="/wallet/wallet"
export PASSWORD_FILE="/wallet/password"


# Create new wallet if it doesn't exist
if [[ ! -f ${WALLET_FILE} ]]; then
  echo $WALLET_CREDS > ${PASSWORD_FILE}
  wownero-wallet-cli \
    --generate-new-wallet ${WALLET_FILE} \
    --daemon-address ${DAEMON_URI} \
    --password-file ${PASSWORD_FILE} \
    --trusted-daemon \
    --use-english-language-names \
    --mnemonic-language English \
    --command status
fi

# Run RPC wallet
wownero-wallet-rpc \
  --daemon-address ${DAEMON_URI} \
  --wallet-file ${WALLET_FILE} \
  --password-file ${PASSWORD_FILE} \
  --rpc-bind-port 8000 \
  --rpc-bind-ip 0.0.0.0 \
  --confirm-external-bind \
  --log-file ${WALLET_FILE}.rpc.log \
  --log-level 0 \
  --non-interactive \
  --trusted-daemon \
  --tx-notify="/usr/bin/curl -s -X GET http://btcpayserver:49392/wownerolikedaemoncallback/tx?cryptoCode=wow&hash=%s"
