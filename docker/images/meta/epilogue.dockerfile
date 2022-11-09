ARG IMAGE
FROM $IMAGE AS base

FROM base AS epilogue-bash-user-wo3sglfw

SHELL ["/bin/bash", "-c"]

ARG DOCKER_USERNAME

ARG _HOME="/home/$DOCKER_USERNAME"

ENV BASH_ENV="$_HOME/.profile"

USER $DOCKER_USERNAME
WORKDIR $_HOME
