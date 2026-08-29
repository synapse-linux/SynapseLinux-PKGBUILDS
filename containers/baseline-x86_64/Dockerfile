# syntax=docker/dockerfile:1
# Arch Linux base-devel amd64 image manifest from 2026-08-24.
ARG BASE_IMAGE="docker.io/library/archlinux@sha256:a26046b7363dad8e2614858f4313949ae9b05c9c5f31de343a54864b9e20806f"
FROM ${BASE_IMAGE}

ARG ARCH_SNAPSHOT="2026/08/29"

LABEL org.opencontainers.image.title="SynapseLinux x86-64 baseline package builder" \
      org.opencontainers.image.description="Pinned clean Arch environment for SynapseLinux PKGBUILDs" \
      org.opencontainers.image.source="https://github.com/synapse-linux/SynapseLinux-PKGBUILDS" \
      org.synapse.arch-snapshot="${ARCH_SNAPSHOT}"

RUN printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "${ARCH_SNAPSHOT}" \
        > /etc/pacman.d/mirrorlist \
    && pacman --noconfirm --disable-download-timeout -Syyu \
    && pacman --noconfirm --needed -S \
        desktop-file-utils \
        glibc-locales \
        libxml2 \
        namcap \
        python \
        qt6-base \
        qt6-tools \
        shared-mime-info \
        shellcheck \
        sqlite \
    && rm -rf /var/cache/pacman/pkg/* \
    && locale -a | grep -Fxq en_US.utf8 \
    && locale -a | grep -Fxq it_IT.utf8

COPY containers/baseline-x86_64/run-build.sh /usr/local/bin/synapse-pkgbuild-baseline
RUN chmod 0755 /usr/local/bin/synapse-pkgbuild-baseline

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

WORKDIR /workspace
CMD ["/usr/local/bin/synapse-pkgbuild-baseline", "/workspace", "/output"]
