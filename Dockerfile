FROM ghcr.io/gleam-lang/gleam:v1.19.2-erlang-alpine AS gleam

FROM erlang:28-alpine AS development

RUN apk add --no-cache build-base ca-certificates git
COPY --from=gleam /bin/gleam /usr/local/bin/gleam

WORKDIR /workspace
COPY gleam.toml manifest.toml ./
RUN gleam deps download
COPY . .

CMD ["sleep", "infinity"]
