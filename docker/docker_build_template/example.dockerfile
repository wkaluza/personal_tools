FROM ubuntu:20.04

ARG UID
ARG GID
ARG USERNAME

ARG _HOME="/home/$USERNAME"
ENV WORKSPACE="$_HOME/workspace"

ARG _DOCKER_BUILD_TEMP_ROOT_DIR="/docker_build_temp"
ARG _DOCKER_BUILD_TEMP_USER_DIR="$WORKSPACE/docker_build_temp"

SHELL ["/bin/bash", "-c"]

COPY create_user_workspace.sh $_DOCKER_BUILD_TEMP_ROOT_DIR/
RUN $_DOCKER_BUILD_TEMP_ROOT_DIR/create_user_workspace.sh \
$UID \
$GID \
$USERNAME \
$WORKSPACE

COPY system_setup_root.sh $_DOCKER_BUILD_TEMP_ROOT_DIR/
RUN $_DOCKER_BUILD_TEMP_ROOT_DIR/system_setup_root.sh
RUN rm -rf $_DOCKER_BUILD_TEMP_ROOT_DIR

USER $USERNAME
WORKDIR $WORKSPACE

COPY --chown=$UID:$GID system_setup_user.sh $_DOCKER_BUILD_TEMP_USER_DIR/
RUN $_DOCKER_BUILD_TEMP_USER_DIR/system_setup_user.sh
RUN rm -rf $_DOCKER_BUILD_TEMP_USER_DIR

CMD ["/bin/bash"]
