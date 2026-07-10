# Stanford Stages - automated sleep stage scoring and narcolepsy identification.
#
# Python 3.7 is required by the pinned scientific stack (scipy 1.3.2,
# scikit-image 0.15.0, pandas 0.25.1, numpy 1.19.5). Newer interpreters will
# fail to find wheels for those versions.
FROM python:3.7-slim

# Build toolchain and runtime libraries needed by pyedflib, h5py, matplotlib
# and TensorFlow. libgl1 / libglib2.0-0 satisfy shared libraries that some
# wheels dlopen at import time.
# Point apt at the GWDG Debian mirror. The base image's default deb.debian.org /
# security.debian.org hosts serve over HTTP, which is blocked on the GWDG network.
ARG DEBIAN_MIRROR=https://ftp.gwdg.de/pub/linux/debian/debian
ARG DEBIAN_SECURITY_MIRROR=https://ftp.gwdg.de/pub/linux/debian/debian-security
RUN for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do \
      [ -f "$f" ] || continue; \
      sed -i -E \
        -e "s#https?://(deb\.debian\.org|security\.debian\.org)/debian-security#${DEBIAN_SECURITY_MIRROR}#g" \
        -e "s#https?://deb\.debian\.org/debian#${DEBIAN_MIRROR}#g" \
        "$f"; \
    done

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        pkg-config \
        python3-dev \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    MPLBACKEND=Agg \
    PIP_CONSTRAINT=/tmp/constraints.txt

WORKDIR /app

# Install Python dependencies first so this layer is cached when only the
# source code changes. The constraints file pins Cython<3 so that the
# source build of pyedflib 0.1.22 succeeds (see docker/constraints.txt).
COPY docker/requirements.txt /tmp/requirements.txt
COPY docker/constraints.txt /tmp/constraints.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Copy the application source and the committed ML assets (scaling files and
# noiseM.mat). The large ac/ LSTM models are NOT copied; they are mounted as
# a volume at runtime (see docker-compose.yml).
COPY . /app

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Default input/output mount points. Override with -v or docker-compose.
RUN mkdir -p /data/input /data/output

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
