ARG CONTAINER_REGISTRY=""
ARG IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:latest
FROM ${CONTAINER_REGISTRY}${IMAGE}

LABEL org.opencontainers.image.title="Eclipse Temurin Grype Package Scanner" \
      org.opencontainers.image.description="Containerized Grype vulnerability scanner for Eclipse Temurin Linux packages"

# Install archive extraction tools, Python 3, and utility dependencies
RUN microdnf install -y \
        tar \
        gzip \
        xz \
        cpio \
        rpm \
        binutils \
        python3 \
        bash \
        findutils \
        shadow-utils \
    && microdnf clean all \
    && rm -rf /var/cache/yum

# Install Anchore Grype standalone binary
ARG GRYPE_VERSION=""
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin ${GRYPE_VERSION}

# Create unprivileged user for running scans
RUN groupadd -g 10001 scanner \
    && useradd -m -d /home/scanner -u 10000 -g 10001 scanner

# Copy scanner scripts and configuration files into the container image
COPY --chown=scanner:scanner . /opt/grype/
RUN chmod +x /opt/grype/*.sh /opt/grype/*.py 2>/dev/null || true

# Set working directory and default non-root user
WORKDIR /work
USER 10000

ENTRYPOINT ["/bin/bash", "/opt/grype/run-all-scans.sh"]
CMD ["--search-dir", "/work", "--output-dir", "/work/build/grype-results"]
