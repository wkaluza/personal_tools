ARG IMAGE
FROM $IMAGE AS base

ARG _DOCKER_BUILD_TEMP_ROOT_DIR="/docker_root_build_temp"
ARG _IMAGE_SETUP_SCRIPT="set_up_image.bash"

COPY $_IMAGE_SETUP_SCRIPT $_DOCKER_BUILD_TEMP_ROOT_DIR/
RUN bash $_DOCKER_BUILD_TEMP_ROOT_DIR/$_IMAGE_SETUP_SCRIPT
RUN rm -rf $_DOCKER_BUILD_TEMP_ROOT_DIR