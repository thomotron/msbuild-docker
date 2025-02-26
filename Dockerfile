# build arguments
ARG UBUNTU_VERSION="20.04"
ARG USER_ID
ARG GROUP_ID
ARG SOLUTION_DIR

FROM ubuntu:${UBUNTU_VERSION}

# environment variables
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER_ID=${USER_ID:-1000}
ENV GROUP_ID=${GROUP_ID:-1000}
ENV SOLUTION_DIR=${SOLUTION_DIR:-/src}

# copy scripts
COPY bin /usr/bin

# install available updates, add the wine repository and install the required packages
RUN apt-get update && \
    apt-get full-upgrade --yes && \
    apt-get install --yes wget software-properties-common xvfb && \
    dpkg --add-architecture i386 && \
    wget -qO- https://dl.winehq.org/wine-builds/winehq.key | apt-key add - && \
    apt-add-repository "deb http://dl.winehq.org/wine-builds/ubuntu/ $(lsb_release -cs) main" && \
    wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install --install-recommends --yes winehq-stable winbind cabextract && \
    wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/bin/winetricks && \
    chmod +x /usr/bin/winetricks && \
    apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# create a new user called runner (running things as root is not necessary at this point anymore), create the src folder and give the user full permission to that folder
RUN groupadd --gid ${GROUP_ID} runner && \
    useradd --create-home --uid ${USER_ID} --gid ${GROUP_ID} runner && \
    mkdir /src && \
    chown -R ${USER_ID}:${GROUP_ID} /src && \
    mkdir /opt/msbuild && \
    chown -R ${USER_ID}:${GROUP_ID} /opt/msbuild
USER runner

# install Windows SDK
COPY --chown=${USER_ID}:${GROUP_ID} build/install_sdks.sh /tmp/
RUN xvfb-run /tmp/install_sdks.sh && \
    rm -r ${HOME}/.cache/* /tmp/*

# copy build tools, reference assemblies, and .NET SDK into the container
COPY --chown=${USER_ID}:${GROUP_ID} /artifacts/artifacts/vs_buildtools /opt/msbuild/vs_buildtools
COPY --chown=${USER_ID}:${GROUP_ID} ["/artifacts/artifacts/Reference Assemblies", "/home/runner/.wine/drive_c/Program Files (x86)/Reference Assemblies"]
COPY --chown=${USER_ID}:${GROUP_ID} ["/artifacts/artifacts/dotnet", "/home/runner/.wine/drive_c/Program Files/dotnet"]

# fix winsdk script
# this if-statement condition ALWAYS fails under wine, seems to be a wine bug?
RUN sed -i 's/\"!result:~0,3!\"==\"10.\"/\"1\"==\"1\"/g' /opt/msbuild/vs_buildtools/Common7/Tools/vsdevcmd/core/winsdk.bat

# set working directory to /src (or Z:\src in wine terms)
WORKDIR /src
VOLUME ["/src"]

# set vs_cmd as entrypoint
ENTRYPOINT ["vs_cmd"]

# pass "cmd" as argument to vs_cmd by default, this will open a command prompt
CMD ["cmd"]
