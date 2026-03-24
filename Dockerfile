FROM debian:stable-slim AS build

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      libad9361-dev \
      libbladerf-dev \
      libiio-dev \
      libncurses-dev \
      libprotobuf-c-dev \
      librrd-dev \
      librtlsdr-dev \
      make \
      pkg-config \
      protobuf-c-compiler \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY ./ /src

WORKDIR /src

RUN make all RTLSDR=yes BLADERF=yes PLUTOSDR=yes

FROM debian:stable-slim

COPY --from=build /src/entrypoint.sh /src/readsb /src/readsbrrd /src/viewadsb /usr/local/bin/

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      curl \
      libad9361-0 \
      libbladerf2 \
      libiio0 \
      libncurses6 \
      libprotobuf-c1 \
      librrd8 \
      librtlsdr0 \
      lighttpd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

EXPOSE 8080 30001-30005

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
