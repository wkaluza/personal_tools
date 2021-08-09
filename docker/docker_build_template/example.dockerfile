FROM ubuntu:20.04

ARG UID
ARG GID
ARG USERNAME
ARG WORKSPACE

SHELL ["/bin/bash", "-c"]

ENV TEMP_CONTAINER_SETUP_DIR="/docker_setup_temp"

COPY user_workspace_setup.sh \
system_setup.sh \
$TEMP_CONTAINER_SETUP_DIR/

RUN $TEMP_CONTAINER_SETUP_DIR/user_workspace_setup.sh \
$UID \
$GID \
$USERNAME \
$WORKSPACE
RUN $TEMP_CONTAINER_SETUP_DIR/system_setup.sh
RUN rm -rf $TEMP_CONTAINER_SETUP_DIR

ENV TEMP_CONTAINER_SETUP_DIR=""

USER $USERNAME

CMD ["/bin/bash"]
