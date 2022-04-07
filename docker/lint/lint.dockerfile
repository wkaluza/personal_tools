FROM ubuntu:22.04

ARG UID
ARG GID
ARG USERNAME

ARG _HOME="/home/$USERNAME"
ENV WORKSPACE="$_HOME/workspace"

ARG _DOCKER_BUILD_TEMP_ROOT_DIR="/docker_root_build_temp"
ARG _DOCKER_BUILD_TEMP_USER_DIR="$_HOME/docker_user_build_temp"

SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get upgrade --yes --with-new-pkgs

COPY create_user_workspace.bash $_DOCKER_BUILD_TEMP_ROOT_DIR/
RUN bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/create_user_workspace.bash \
$UID \
$GID \
$USERNAME \
$WORKSPACE

COPY system_setup_root.bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/
COPY files_common/ \
$_DOCKER_BUILD_TEMP_ROOT_DIR/files_common/
COPY files_root/ \
$_DOCKER_BUILD_TEMP_ROOT_DIR/files_root/

RUN source /etc/profile \
&& \
IMPORTS_DIR="$_DOCKER_BUILD_TEMP_ROOT_DIR" \
bash \
$_DOCKER_BUILD_TEMP_ROOT_DIR/system_setup_root.bash \
&& \
rm -rf $_DOCKER_BUILD_TEMP_ROOT_DIR

USER $USERNAME

COPY --chown=$UID:$GID system_setup_user.bash \
$_DOCKER_BUILD_TEMP_USER_DIR/
COPY --chown=$UID:$GID files_common/ \
$_DOCKER_BUILD_TEMP_USER_DIR/files_common/
COPY --chown=$UID:$GID files_user/ \
$_DOCKER_BUILD_TEMP_USER_DIR/files_user/

RUN source /etc/profile \
&& \
IMPORTS_DIR="$_DOCKER_BUILD_TEMP_USER_DIR" \
bash \
$_DOCKER_BUILD_TEMP_USER_DIR/system_setup_user.bash \
&& \
rm -rf $_DOCKER_BUILD_TEMP_USER_DIR

WORKDIR $WORKSPACE

CMD ["/bin/bash"]
