ARG BASE_IMAGE=base
ARG VARIANT=debian

FROM mcr.microsoft.com/devcontainers/${BASE_IMAGE}:${VARIANT} AS base

# Build-time metadata as defined at https://github.com/opencontainers/image-spec/blob/master/annotations.md
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.url="https://github.com/klein2ms/base-devcontainer" \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.documentation="https://github.com/klein2ms/base-devcontainer" \
    org.opencontainers.image.source="https://github.com/klein2ms/base-devcontainer" \
    org.opencontainers.image.title="base-devcontainer" \
    org.opencontainers.image.description="A base development container for Visual Studio Code"

ARG BUILD_DEPS="curl gnupg gnupg2 lsb-release software-properties-common"
ARG APP_DEPS="build-essential libc-dev libfontconfig1 libpq-dev libssl-dev libxml2 libxml2-dev libxslt1-dev libxslt1.1 libz-dev unixodbc-dev"
ENV EDITOR=nano
ENV TERM=xterm

ONBUILD ARG USERNAME=vscode
ONBUILD ARG USER_UID=1000
ONBUILD ARG USER_GID=$USER_UID

ONBUILD ARG ENABLE_NONROOT_DOCKER="true"
ONBUILD ARG SOURCE_SOCKET=/var/run/docker-host.sock
ONBUILD ARG TARGET_SOCKET=/var/run/docker.sock

COPY scripts/ /tmp/scripts/
COPY ./config/starship.toml /root/.config/

RUN set -ex \
    # Install build tools
    && apt-get update \
    && apt-get install --no-install-recommends -y $BUILD_DEPS \
    && apt-get install --no-install-recommends -y $APP_DEPS \
    && apt-get update \
    && apt-get install --no-install-recommends -y fonts-powerline fonts-firacode gh
RUN curl -sS https://starship.rs/install.sh | sh -y \
    # && curl -s https://api.github.com/repos/starship/starship/releases/latest \
    # | grep browser_download_url \
    # | grep x86_64-unknown-linux-gnu \
    # | cut -d '"' -f 4 \
    # | wget -qi - \
    # && tar xvf starship-*.tar.gz \
    # && mv starship /usr/local/bin/ \
    # && rm starship-*.tar.gz \
    && echo 'eval "$(starship init zsh)"' >> /root/.zshrc \
    && gh completion -s zsh > /usr/local/share/zsh/site-functions/_gh \
    && gh config set editor "code --wait" \
    # Configure Editor
    && apt-get update -y \
    && apt-get install -y --no-install-recommends nano locales-all \
    && echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
    && locale-gen en_US.UTF-8 \
    && apt-get purge -y locales-all \
    # Allow devcontainer to access host docker socket
    && bash /tmp/scripts/docker-debian.sh "${ENABLE_NONROOT_DOCKER}" "${SOURCE_SOCKET}" "${TARGET_SOCKET}" "${USERNAME}" \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists

ONBUILD RUN echo 'eval "$(starship init zsh)"' >> /home/$USERNAME/.zshrc \
    && mkdir -p /home/$USERNAME/.config \
    && chown -R $USER_UID:$USER_GID /home/$USERNAME/.config \
    && chmod -R 700 /home/$USERNAME/.config \
    && cp /root/.config/starship.toml /home/$USERNAME/.config/ \
    && chown $USER_UID:$USER_GID /home/$USERNAME/.config/starship.toml \
    # Update UID/GID if needed
    && if [ "$USER_GID" != "1000" ] || [ "$USER_UID" != "1000" ]; then \
    groupmod --gid $USER_GID $USERNAME \
    && usermod --uid $USER_UID --gid $USER_GID $USERNAME \
    && chmod -R $USER_UID:$USER_GID /home/$USERNAME; \
    fi

ONBUILD ARG DEBIAN_DEPS=""
# Install apt-get packages
ONBUILD RUN if [ ! -z "$DEBIAN_DEPS" ]; then \
    export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install --no-install-recommends -y $DEBIAN_DEPS \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/library-scripts; \
    fi

ONBUILD ARG NPM_DEPS=""
ONBUILD ARG NODE_VERSION="lts/*"
ENV NVM_DIR=/usr/local/share/nvm
ENV NVM_SYMLINK_CURRENT=true \
    PATH=${NVM_DIR}/current/bin:${PATH}
# Install node and npm packages
ONBUILD RUN if [ ! -z "$NPM_DEPS" ]; then \
    bash /tmp/scripts/install-node.sh "${NVM_DIR}" "${NODE_VERSION}" "${USERNAME}" \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/library-scripts; \
    fi
ONBUILD RUN if [ ! -z "$NPM_DEPS" ]; then \
    npm install -g $NPM_DEPS; \
    fi

ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]

FROM base AS devcontainer