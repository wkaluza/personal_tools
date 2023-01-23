ARG IMAGE
FROM $IMAGE AS base

ARG _TEMP_DIR_ROOT="/docker_root_build_temp"
ARG _SETUP_SCRIPT_ROOT="$_TEMP_DIR_ROOT/set_up_image_root.bash"

USER root
COPY "./" $_TEMP_DIR_ROOT/
RUN bash $_SETUP_SCRIPT_ROOT
RUN rm -rf $_TEMP_DIR_ROOT
