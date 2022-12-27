FROM ubuntu:focal

WORKDIR /workspace

COPY "./" "/docker/"
RUN bash "/docker/build_cred_helper.bash"
