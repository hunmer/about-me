FROM dart:3.13 AS build

WORKDIR /src/packages/aboutme_server
COPY packages/aboutme_server/pubspec.yaml packages/aboutme_server/pubspec.lock ./
COPY packages/aboutme_data_sdk /src/packages/aboutme_data_sdk
COPY shared_models /src/shared_models
RUN dart pub get

COPY packages/aboutme_server /src/packages/aboutme_server
RUN mkdir -p /app \
    && dart pub get --offline \
    && dart compile exe bin/server.dart -o /app/aboutme-server

FROM debian:bookworm-slim

RUN groupadd --system aboutme \
    && useradd --system --gid aboutme --home-dir /app --no-create-home aboutme \
    && mkdir -p /app/data \
    && chown -R aboutme:aboutme /app

WORKDIR /app
COPY --from=build /app/aboutme-server /app/aboutme-server
COPY --from=build /src/packages/aboutme_server/admin /app/admin
COPY --from=build /src/packages/aboutme_server/debug /app/debug
RUN chown -R aboutme:aboutme /app

ENV PORT=8874 \
    DATA_DIR=/app/data \
    ADMIN_DIR=/app/admin
EXPOSE 8874
USER aboutme
ENTRYPOINT ["/app/aboutme-server"]
