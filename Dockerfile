# Stage 1: Build
FROM elixir:1.18-slim AS builder

RUN apt-get update -y && \
    apt-get install -y build-essential git curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

# Install hex and rebar
RUN mix local.hex --force && mix local.rebar --force

# Fetch dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy config to compile dependencies
COPY config/config.exs config/prod.exs config/

# Compile dependencies
RUN mix deps.compile

# Copy assets and build them
COPY assets/ assets/
COPY priv/ priv/
COPY lib/ lib/

RUN mix compile
RUN mix assets.deploy

# Build release
COPY config/runtime.exs config/
RUN mix release

# Stage 2: Runner — pakai base image yang sama dengan builder agar OpenSSL & GLIBC selalu cocok
FROM elixir:1.18-slim AS runner

RUN apt-get update -y && \
    apt-get install -y locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    PHX_SERVER=true

WORKDIR /app

RUN useradd --create-home app
USER app

COPY --from=builder --chown=app:app /app/_build/prod/rel/wa_gate ./

EXPOSE 4000

CMD ["sh", "-c", "bin/wa_gate eval 'WaGate.Release.migrate()' && bin/wa_gate start"]
