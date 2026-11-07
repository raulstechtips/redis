FROM debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc AS build

ARG REDIS_VERSION=8.2.11
ARG REDIS_SHA256=fba14b77c4bdcb2d5418b6741fc0cdaac4b78bc73eab9b2e5f3c255d597f16fa
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl build-essential libssl-dev pkg-config \
    && curl --fail --show-error --location "https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz" -o /tmp/redis.tar.gz \
    && echo "${REDIS_SHA256}  /tmp/redis.tar.gz" | sha256sum --check - \
    && mkdir /build \
    && tar -xzf /tmp/redis.tar.gz -C /build --strip-components=1 \
    && make -C /build -j2 BUILD_TLS=yes MALLOC=libc OPT="-O2" \
    && strip /build/src/redis-server /build/src/redis-cli

FROM debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 redis \
    && useradd --uid 10001 --gid 10001 --no-create-home --home-dir /data --shell /usr/sbin/nologin redis \
    && mkdir -p /data /run/redis /usr/share/redis \
    && chown redis:redis /data /run/redis \
    && dpkg-query -W > /usr/share/redis/packages.txt
COPY --from=build /build/src/redis-server /build/src/redis-cli /usr/local/bin/
COPY --from=build /build/LICENSE.txt /usr/share/redis/LICENSE.txt
COPY config/ /etc/redis/
COPY scripts/ /usr/local/lib/redis/
RUN chmod 0555 /usr/local/lib/redis/*.sh
USER 10001:10001
WORKDIR /data
EXPOSE 6379 26379
ENTRYPOINT ["/usr/local/lib/redis/entrypoint.sh"]
CMD ["redis"]
