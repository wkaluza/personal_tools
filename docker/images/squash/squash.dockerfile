ARG IMAGE
FROM $IMAGE AS base

FROM scratch AS flat-lu5k0qbb

COPY --from=base / /

FROM flat-lu5k0qbb AS flat-bash-user-wo3sglfw

SHELL ["/bin/bash", "-c"]

ARG USERNAME

ARG _HOME="/home/$USERNAME"

ENV BASH_ENV="$_HOME/.profile"

USER $USERNAME
WORKDIR $_HOME
