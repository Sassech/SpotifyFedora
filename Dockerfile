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

COPY build-spotify.sh /build/
COPY create-spec.sh /build/

RUN chmod +x /build/build-spotify.sh /build/create-spec.sh

CMD ["/build/build-spotify.sh"]
