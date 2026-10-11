# Desktop preview: Qt 5.15 + PyOtherSide with a Silica stand-in (preview/shim).
FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587
# Packages come from a fixed Debian snapshot, so the image is reproducible.
ARG SNAPSHOT=20261001T000000Z
RUN rm -f /etc/apt/sources.list.d/debian.sources \
 && echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/${SNAPSHOT} bookworm main" > /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      qmlscene qml-module-qtquick2 qml-module-qtquick-window2 qml-module-io-thp-pyotherside qml-module-qttest qtdeclarative5-dev-tools \
      qtwayland5 libqt5svg5 python3 fonts-dejavu-core librsvg2-bin \
 && rm -rf /var/lib/apt/lists/*
COPY preview/run.sh /usr/local/bin/preview-run
ENTRYPOINT ["/usr/local/bin/preview-run"]
