# syntax=docker/dockerfile:1
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md#syntax
# see https://docs.docker.com/build/dockerfile/frontend/
# see https://docs.docker.com/engine/reference/builder/#syntax

# renovate: datasource=github-releases depName=dotnet/sdk
ARG DOTNET_SDK_VERSION=9.0.102

# https://mcr.microsoft.com/en-us/artifact/mar/dotnet/sdk/tags
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_VERSION}-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive \
    ASTRO_TELEMETRY_DISABLED=1 \
    NEXT_TELEMETRY_DISABLED=1 \
    DO_NOT_TRACK=1 \
    AWS_REQUEST_CHECKSUM_CALCULATION=when_required \
    AWS_RESPONSE_CHECKSUM_VALIDATION=when_required \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK_OPTOUT=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_CLI_UI_LANGUAGE=en-US \
    DOTNET_SVCUTIL_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_ROLL_FORWARD=Major \
    DOTNET_ROLL_FORWARD_TO_PRERELEASE=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    NUGET_CERT_REVOCATION_MODE=offline \
    NVM_DIR=/root/.nvm \
    DOTNET_ROOT=/usr/share/dotnet \
    BUILDKIT_PROGRESS=plain \
    DOCKER_BUILDKIT=1

# renovate: datasource=github-releases depName=nodejs/node
ENV NODE_VERSION=23.7.0
ENV PATH=${DOTNET_ROOT}:${DOTNET_ROOT}/tools:${NVM_DIR}/:${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/:/root/.local/bin:/root/.dotnet/tools:${PATH}

WORKDIR /tmp
### install git-lfs
# renovate: datasource=github-releases depName=git-lfs/git-lfs
ARG GIT_LFS_VERSION=v3.6.1
ARG TARGETPLATFORM
RUN case ${TARGETPLATFORM} in \
        "linux/amd64") GIT_LFS_ARCH=amd64 ;; \
        "linux/arm64" | "linux/arm/v8") GIT_LFS_ARCH=arm64 ;; \
        "linux/arm/v7") GIT_LFS_ARCH=arm ;; \
        *) echo 'unsupported target platform' ; exit 1; ;; \
    esac && \
    echo "Installing git-lfs for ${TARGETPLATFORM}" && \
    curl -L -s --output git-lfs.tar.gz "https://github.com/git-lfs/git-lfs/releases/download/${GIT_LFS_VERSION}/git-lfs-linux-${GIT_LFS_ARCH}-${GIT_LFS_VERSION}.tar.gz" && \
    tar --strip-components=1 -xf git-lfs.tar.gz && \
    chmod +x git-lfs && \
    rm git-lfs.tar.gz && \
    mv git-lfs /usr/bin/git-lfs && \
    git-lfs --version

### install nvm & nodejs
# https://github.com/nodejs/node/tags
# renovate: datasource=github-releases depName=nodejs/node
ARG NODE_VERSION=23.7.0
# renovate: datasource=github-releases depName=nvm-sh/nvm
ARG NVM_VERSION=v0.40.1

RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default \
    && node --version && npm --version && npx --version

### install packages
RUN apt update -yq \
    && apt install -yq --no-install-recommends --no-install-suggests \
    sudo \
    lsb-release \
    openssh-client \
    jq \
    zip \
    unzip

### install docker
# https://github.com/docker/buildx/tags
# renovate: datasource=github-releases depName=docker/buildx
ARG BUILDX_VERSION=v0.20.1
# https://docs.docker.com/engine/release-notes
# renovate: datasource=docker depName=docker.io/docker versioning=docker
ARG DOCKER_VERSION=27.5.1
# https://github.com/docker/compose/releases
# renovate: datasource=github-releases depName=docker/compose
ARG DOCKER_COMPOSE_VERSION=v2.32.4
ARG TARGETPLATFORM
RUN <<EOF
  case ${TARGETPLATFORM} in
    "linux/amd64") DOCKER_ARCH='x86_64'; DOCKERX_ARCH='amd64'; ;;
    "linux/arm64" | "linux/arm/v8") DOCKER_ARCH='aarch64'; DOCKERX_ARCH='arm64'; ;;
    "linux/arm/v7") DOCKER_ARCH='armhf'; DOCKERX_ARCH='arm-v7'; ;;
    *) echo 'unsupported target platform' ; exit 1; ;;
  esac
  echo "installing docker ${DOCKER_VERSION}-${DOCKER_ARCH}"
  curl -fLs https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz | tar xvz --strip-components=1 --directory /usr/local/bin/
  echo "installing buildx: ${BUILDX_VERSION}-${DOCKERX_ARCH}"
  curl -fLo /usr/local/lib/docker/cli-plugins/docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-${DOCKERX_ARCH}" --create-dirs
  echo "installing compose: ${DOCKER_COMPOSE_VERSION}-${DOCKER_ARCH} "
  curl -fLo /usr/local/lib/docker/cli-plugins/docker-compose "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${DOCKER_ARCH}" --create-dirs
  chmod -R 775 "/usr/local/lib/docker" && \
  ln -sv usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/ && \
  docker -v && docker buildx version && docker compose version
EOF

### install dotnet tools
# renovate: datasource=nuget depName=dotnet-ef
ARG DOTNET_TOOL_EF_VERSION=9.0.2
# renovate: datasource=nuget depName=nbgv
ARG DOTNET_TOOL_NBGV_VERSION=3.7.115
# renovate: datasource=nuget depName=nswag.consolecore
ARG DOTNET_TOOL_NSWAG_VERSION=14.2.0
RUN dotnet tool install -g dotnet-ef --version ${DOTNET_TOOL_EF_VERSION} && \
  dotnet tool install -g nbgv --version ${DOTNET_TOOL_NBGV_VERSION} && \
  dotnet tool install -g nswag.consolecore --version ${DOTNET_TOOL_NSWAG_VERSION}


### cleanup
RUN apt-get clean \
    && rm -rf /var/cache/* /var/log/* /var/lib/apt/lists/* /tmp/* || echo 'Failed to cleanup docker image'

ARG IMAGE_CREATED=2025-01-01T00:00:00Z
ARG IMAGE_VERSION=0.1
ARG IMAGE_REVISION=d3e3023f3938e174462239f855e615fd15e021bf
LABEL org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.authors="Vladimir Chirikov" \
      org.opencontainers.image.url="https://github.com/vchirikov/act-docker-images" \
      org.opencontainers.image.documentation="https://github.com/vchirikov/act-docker-images" \
      org.opencontainers.image.source="https://github.com/vchirikov/act-docker-images" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.vendor="Vladimir Chirikov" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="act-dotnet-bookworm-slim" \
      org.opencontainers.image.description="Act/Gitea Actions runner docker image to run dotnet related workflows."
