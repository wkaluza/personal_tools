ARG IMAGE
FROM $IMAGE AS base

ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USERNAME

ARG _HOME="/home/$DOCKER_USERNAME"
ARG _TEMP_DIR_ROOT="/docker_root_build_temp"
ARG _TEMP_DIR_USER="$_HOME/docker_user_build_temp"
ARG _SETUP_SCRIPT_ROOT="$_TEMP_DIR_ROOT/set_up_image_root.bash"
ARG _SETUP_SCRIPT_USER="$_TEMP_DIR_USER/set_up_image_user.bash"

USER root
COPY "./" $_TEMP_DIR_ROOT/
RUN bash $_SETUP_SCRIPT_ROOT \
"docker_entrypoint.bash" \
"/docker_entrypoint_rmipkca4.bash" \
$DOCKER_UID \
$DOCKER_GID
RUN rm -rf $_TEMP_DIR_ROOT/

USER $DOCKER_USERNAME
COPY --chown=$DOCKER_USERNAME "./" $_TEMP_DIR_USER/
RUN bash $_SETUP_SCRIPT_USER \
"run_texlive.bash" \
"$_HOME/run_texlive_zqn5plgk.bash"
RUN rm -rf $_TEMP_DIR_USER/
