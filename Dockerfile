# syntax=docker/dockerfile:1
# Production image for MadTech News (lobsters fork). Multi-stage build.
# Build:  docker compose -f docker-compose.prod.yml build
ARG RUBY_VERSION=4.0.0

############################
# Base (shared) layer
############################
FROM ruby:${RUBY_VERSION}-slim AS base

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

WORKDIR /app

# Runtime OS packages: libvips (image processing), curl (healthcheck), tzdata, jemalloc.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      libvips libjemalloc2 curl tzdata && \
    rm -rf /var/lib/apt/lists/*

############################
# Build layer (compiles gems + assets)
############################
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential clang git pkg-config libvips-dev libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

# Install gems first for better layer caching.
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy the application source.
COPY . .

# database.yml is gitignored; render it from the committed sample.
# Also create runtime dirs the production logger expects (log/rails.log) — git
# doesn't track empty dirs and .dockerignore strips their contents.
RUN cp config/database.yml.sample config/database.yml && \
    mkdir -p log tmp storage public/cache

# Precompile assets. SECRET_KEY_BASE_DUMMY lets this run without a real secret,
# RAILS_SERVE_STATIC_FILES keeps the digest manifest happy.
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_SERVE_STATIC_FILES=true \
    bundle exec rails assets:precompile

############################
# Final runtime image
############################
FROM base AS final

# Copy installed gems and the built app from the build stage.
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /app /app

# Run as an unprivileged user; make runtime dirs writable.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p log tmp storage public/cache && \
    chown -R rails:rails db log tmp storage public/cache
USER rails:rails

ENTRYPOINT ["/app/bin/docker-entrypoint"]

EXPOSE 3000
# Bind to :3000 (puma.rb sets no port, so it would otherwise default to 9292).
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "-p", "3000"]
