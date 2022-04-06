FROM ubuntu:22.04

ARG USER_ID
ARG GROUP_ID
ARG USERNAME
ARG TIMEZONE
ARG DOCKER_GROUP_ID

ENV USER=$USERNAME
ENV UID=$USER_ID
ENV HOST_TIMEZONE=$TIMEZONE

ARG _HOME=/home/$USERNAME
ARG _WORKSPACE=$_HOME/workspace

SHELL ["bash","-c"]

RUN apt-get update
RUN apt-get install --yes sudo

RUN addgroup \
--gid "$GROUP_ID" \
"$USERNAME"

RUN adduser \
--disabled-password \
--gecos "" \
--gid "$GROUP_ID" \
--home "$(realpath $_HOME)" \
--shell "/bin/bash" \
--uid "$USER_ID" \
"$USERNAME"

RUN mkdir --parents $_WORKSPACE
COPY ubuntu_bare_minimum.bash $_WORKSPACE/
RUN chown --recursive $USERNAME:$USERNAME $_WORKSPACE

RUN adduser "$USERNAME" sudo
RUN echo "%sudo ALL=(ALL) NOPASSWD:ALL" >>"/etc/sudoers"

RUN addgroup \
--gid "$DOCKER_GROUP_ID" \
docker

RUN adduser "$USERNAME" docker

USER $USERNAME

WORKDIR $_WORKSPACE
