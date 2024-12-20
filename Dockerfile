FROM lalanza808/wownero:v0.11.3.0

RUN apt update && apt install curl -y

WORKDIR /wallet

EXPOSE 34568

COPY run_wallet.sh /run_wallet.sh
