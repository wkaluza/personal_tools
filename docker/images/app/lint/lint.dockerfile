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
ARG _GO_ROOT="/usr/local/go"

ENV GOROOT="$_GO_ROOT"
ENV PATH="$_GO_ROOT/bin:$_HOME/go/bin:$_HOME/.local/bin:$_HOME/.yarn/bin:$PATH"

USER root
COPY "./" $_TEMP_DIR_ROOT/
RUN bash $_SETUP_SCRIPT_ROOT \
"docker_entrypoint.bash" \
"/docker_entrypoint_szmbg3jl.bash" \
$DOCKER_UID \
$DOCKER_GID \
$_GO_ROOT
RUN rm -rf $_TEMP_DIR_ROOT/

USER $DOCKER_USERNAME
COPY --chown=$DOCKER_USERNAME "./" $_TEMP_DIR_USER/
RUN bash $_SETUP_SCRIPT_USER \
"lint.bash" \
"$_HOME/lint_rpbexfju.bash"
RUN rm -rf $_TEMP_DIR_USER/

ENTRYPOINT ["bash", "/docker_entrypoint_szmbg3jl.bash"]
