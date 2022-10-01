ARG IMAGE="ubuntu:22.04"
FROM $IMAGE

RUN apt-get update
RUN apt-get upgrade --yes
RUN apt-get install --yes \
dnsutils \
curl
