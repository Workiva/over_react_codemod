FROM python:2.7.15 as build

# Build Environment Vars
ARG BUILD_ID
ARG BUILD_NUMBER
ARG BUILD_URL
ARG GIT_COMMIT
ARG GIT_BRANCH
ARG GIT_TAG
ARG GIT_COMMIT_RANGE
ARG GIT_HEAD_URL
ARG GIT_MERGE_HEAD
ARG GIT_MERGE_BRANCH

WORKDIR /build/
ADD . /build/

RUN make install
RUN make test
RUN make dist

ARG BUILD_ARTIFACTS_EXE_DART1_AND_DART2=/build/dist/over_react_migrate_to_dart1_and_dart2
# ARG BUILD_ARTIFACTS_EXE_DART2=/build/dist/over_react_migrate_to_dart2

FROM scratch