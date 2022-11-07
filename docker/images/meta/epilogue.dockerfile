ARG IMAGE
FROM $IMAGE AS base

FROM base AS epilogue-bash-user-wo3sglfw

SHELL ["/bin/bash", "-c"]

ARG USERNAME

ARG _HOME="/home/$USERNAME"

ENV BASH_ENV="$_HOME/.profile"

USER $USERNAME
WORKDIR $_HOME
