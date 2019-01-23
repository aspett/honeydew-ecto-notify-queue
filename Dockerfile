# Elixir: https://hub.docker.com/_/elixir/
FROM elixir:1.7

LABEL name="elixir testing app" \
      version="1.0.0"

ENV MIX_ENV=test

RUN  echo "Install packages" \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y update \
  && apt-get install -qq -y \
      locales \
      curl \
      inotify-tools \
  && echo "Setup locales" \
  && localedef -c -i en_NZ -f UTF-8 en_NZ.UTF-8 \
  && update-locale LANG=en_NZ.UTF-8 \
  && echo "Setup timezone" \
  && echo "Pacific/Auckland" > /etc/timezone \
  && dpkg-reconfigure -f noninteractive tzdata \
  && echo "Cleaning up" \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN echo "Install hex, rebar and Phoenix framework" \
  && mix local.hex --force \
  && mix local.rebar --force

WORKDIR /opt/app

COPY mix.exs mix.lock ./
RUN mix deps.get
RUN mix compile
RUN rm -rf deps/*/.fetch # these files seem to only be removed on a full project compile, and without this here, running mix.test will think it needs to compile deps. https://github.com/elixir-lang/elixir/issues/5130

COPY . .

CMD ["mix", "test"]
