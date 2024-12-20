#!/bin/bash

# Push container images for others to download

git submodule update
docker build -t lalanza808/btcpayserver-wownero:v2.0.4 btcpayserver
docker push lalanza808/btcpayserver-wownero:v2.0.4
docker build -t lalanza808/btcpayserver-wownero-wallet:v0.11.3.0 .
docker push lalanza808/btcpayserver-wownero-wallet:v0.11.3.0