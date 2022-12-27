FROM ubuntu:22.04

ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USERNAME
ARG TIMEZONE
ARG DOCKER_SYSTEM_GID

ENV DOCKER_USER=$DOCKER_USERNAME
ENV DOCKER_UID=$DOCKER_UID
ENV HOST_TIMEZONE=$TIMEZONE

ARG _HOME=/home/$DOCKER_USERNAME
ARG _WORKSPACE=$_HOME/workspace

SHELL ["bash","-c"]

RUN apt-get update
RUN apt-get install --yes sudo

RUN addgroup \
--gid "$DOCKER_GID" \
"$DOCKER_USERNAME"

RUN adduser \
--disabled-password \
--gecos "" \
--gid "$DOCKER_GID" \
--home "$(realpath $_HOME)" \
--shell "/bin/bash" \
--uid "$DOCKER_UID" \
"$DOCKER_USERNAME"

RUN mkdir --parents $_WORKSPACE
RUN chown --recursive $DOCKER_USERNAME:$DOCKER_USERNAME $_WORKSPACE

RUN adduser "$DOCKER_USERNAME" sudo
RUN echo "%sudo ALL=(ALL) NOPASSWD:ALL" >>"/etc/sudoers"

RUN addgroup \
--gid "$DOCKER_SYSTEM_GID" \
docker

RUN adduser "$DOCKER_USERNAME" docker

USER $DOCKER_USERNAME

WORKDIR $_WORKSPACE
