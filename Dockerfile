# syntax=docker/dockerfile:1
FROM fedora:43

ENV LANG=C.UTF-8
ENV BUILDKIT_PROGRESS=plain
WORKDIR /build

RUN --mount=type=cache,target=/var/cache/dnf \
    --mount=type=cache,target=/var/lib/dnf \
    dnf -y update && \
    dnf clean all && \
    dnf install -y --setopt=install_weak_deps=False \
    lsb_release desktop-file-utils python3 make \
    rpm-build rpmdevtools wget curl binutils gtk-update-icon-cache \
    && dnf clean all

RUN groupadd -g 1001 builder && \
    useradd -u 1001 -g builder -s /bin/bash -d /home/builder -m builder && \
    mkdir -p /build && chown -R builder:builder /build

COPY --chown=builder:builder build-spotify.sh create-spec.sh /build/
RUN chmod +x /build/*.sh && rpmdev-setuptree && chown -R builder:builder /root/rpmbuild

ENTRYPOINT ["/bin/bash", "-c", "cd /build && bash build-spotify.sh"]
