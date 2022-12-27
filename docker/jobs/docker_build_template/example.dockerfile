FROM ubuntu:22.04

SHELL ["/bin/bash", "-c"]

ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USERNAME
ARG HOST_TIMEZONE

ARG _ENV_SETUP_SCRIPT="/etc/profile"
ARG _HOME="/home/$DOCKER_USERNAME"
ARG _ROOT_PROFILE="/etc/profile.d/docker_profile.sh"
ARG _USER_PROFILE="$_HOME/.profile"
ARG _DOCKER_BUILD_TEMP_ROOT_DIR="/docker_root_build_temp"
ARG _DOCKER_BUILD_TEMP_USER_DIR="$_HOME/docker_user_build_temp"

ENV ENV="$_ENV_SETUP_SCRIPT" \
BASH_ENV="$_ENV_SETUP_SCRIPT"

ENV DOCKER_PROFILE="$_ROOT_PROFILE"
ENV TZ="$HOST_TIMEZONE"
ENV WORKSPACE="$_HOME/workspace"

COPY configure_container.bash $_DOCKER_BUILD_TEMP_ROOT_DIR/
RUN bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/configure_container.bash

COPY configure_profile.bash $_DOCKER_BUILD_TEMP_ROOT_DIR/
RUN bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/configure_profile.bash \
"$_ROOT_PROFILE"

COPY create_user_workspace.bash $_DOCKER_BUILD_TEMP_ROOT_DIR/
RUN bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/create_user_workspace.bash \
$DOCKER_UID \
$DOCKER_GID \
$DOCKER_USERNAME \
$WORKSPACE

COPY system_setup_root.bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/
COPY files_common/ \
$_DOCKER_BUILD_TEMP_ROOT_DIR/files_common/
COPY files_root/ \
$_DOCKER_BUILD_TEMP_ROOT_DIR/files_root/

RUN IMPORTS_DIR="$_DOCKER_BUILD_TEMP_ROOT_DIR" \
bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/system_setup_root.bash \
&& \
rm -rf $_DOCKER_BUILD_TEMP_ROOT_DIR

USER $DOCKER_USERNAME
ENV DOCKER_PROFILE="$_USER_PROFILE"

COPY --chown=$DOCKER_UID:$DOCKER_GID system_setup_user.bash \
$_DOCKER_BUILD_TEMP_USER_DIR/
COPY --chown=$DOCKER_UID:$DOCKER_GID files_common/ \
$_DOCKER_BUILD_TEMP_USER_DIR/files_common/
COPY --chown=$DOCKER_UID:$DOCKER_GID files_user/ \
$_DOCKER_BUILD_TEMP_USER_DIR/files_user/

RUN IMPORTS_DIR="$_DOCKER_BUILD_TEMP_USER_DIR" \
bash \
$_DOCKER_BUILD_TEMP_USER_DIR/system_setup_user.bash \
&& \
rm -rf $_DOCKER_BUILD_TEMP_USER_DIR

WORKDIR $WORKSPACE

CMD ["/bin/bash"]