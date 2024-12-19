FROM lalanza808/wownero:v0.11.3.0

RUN apt update && apt install curl -y

WORKDIR /data

COPY run_wallet.sh /run_wallet.sh
