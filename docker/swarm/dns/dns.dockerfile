ARG IMAGE="coredns/coredns:1.10.0"
FROM $IMAGE

COPY "./" "/docker/"
