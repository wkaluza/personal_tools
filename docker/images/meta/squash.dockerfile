ARG IMAGE
FROM $IMAGE AS base

FROM scratch AS flat-lu5k0qbb

COPY --from=base / /
