FROM fedora:43

RUN dnf -y update && \
    dnf -y install \
    lsb_release \
    desktop-file-utils \
    python3 \
    make \
    rpm-build \
    rpmdevtools \
    wget \
    curl \
    binutils \
    gtk-update-icon-cache \
    && dnf clean all

RUN rpmdev-setuptree

WORKDIR /build

RUN wget -q -O spotify-make.tar.gz https://github.com/leamas/spotify-make/tarball/master && \
    tar xzf spotify-make.tar.gz && \
    mv leamas-spotify-make-* spotify-make && \
    rm spotify-make.tar.gz

COPY build-spotify.sh /build/
COPY create-spec.sh /build/

RUN chmod +x /build/build-spotify.sh /build/create-spec.sh

CMD ["/build/build-spotify.sh"]
