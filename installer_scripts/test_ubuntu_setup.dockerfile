FROM ubuntu:20.04

RUN apt-get update && \
apt-get upgrade -y && \
apt-get install -y sudo

# Allow passwordless sudo
RUN adduser --disabled-password --gecos '' someuser && \
adduser someuser sudo && \
echo '%sudo ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers

USER someuser

WORKDIR /home/someuser/workspace
