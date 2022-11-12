ARG IMAGE
FROM $IMAGE AS base

COPY "./" "/docker/"
