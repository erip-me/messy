FROM timbru31/ruby-node:3.3

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev \
    imagemagick \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app
WORKDIR /app

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
COPY Gemfile Gemfile.lock ./

RUN gem install bundler

RUN bundle config set --local without 'development test' && \
    bundle install --jobs 20 --retry 5

# Set Rails to run in production to allow assets to build
ENV RAILS_ENV production
ENV RACK_ENV production

# Secrets are injected at runtime: RAILS_MASTER_KEY or SECRET_KEY_BASE via the
# deployment (k8s secret, compose .env). Nothing at build time needs them.

# Helps with docker vi editing
ENV TERM vt100

# Copy the main application.
COPY . ./

# Build the embeddable chat widget JS
RUN npm install --production=false && npm run build

# Create pids folder manually
RUN mkdir -p tmp/pids

# Run as a non-root user. /data is the ActiveStorage root for docker-compose
# (a fresh named volume mounted there inherits this ownership); the app dir
# holds tmp/pids, cache, and the built widget. Kubernetes pins root instead
# via securityContext because its storage volume is root-owned (see deploy/).
RUN groupadd -r app --gid 1000 && useradd -r -g app --uid 1000 --home-dir /app app \
    && mkdir -p /data/storage \
    && chown -R app:app /app /data
USER app

# Start puma only (worker runs on empire cluster via Solid Queue)
CMD bundle exec rails db:prepare && bundle exec puma -C config/puma.rb
