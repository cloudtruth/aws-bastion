FROM ruby:2.6.5-alpine

ENV SVC_ENV="production" \
    SVC_PORT="2222" \
    SVC_DIR="/srv/app" \
    BUNDLE_PATH="/srv/bundler" \
    BUILD_PACKAGES="" \
    APP_PACKAGES="bash curl vim netcat-openbsd tzdata shadow sudo openssh"

# Thes env var definitions reference values from the previous definitions, so they need to be split off on their own.
# Otherwise, they'll receive stale values because Docker will read the values once before it starts setting values.
ENV BUNDLE_BIN="${BUNDLE_PATH}/bin" \
    GEM_HOME="${BUNDLE_PATH}" \
    PATH="${SVC_DIR}:${BUNDLE_BIN}:${PATH}"

RUN mkdir -p $SVC_DIR $BUNDLE_PATH
WORKDIR $SVC_DIR

RUN gem install bundler
COPY Gemfile* $SVC_DIR/
RUN bundle install

RUN apk --update upgrade && \
  apk add \
    --virtual app \
    $APP_PACKAGES && \
  apk add \
    --virtual build_deps \
    $BUILD_PACKAGES && \
  apk add aws-cli --virtual aws_cli --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ && \
  bundle install && \
  apk del build_deps && \
  rm -rf /var/cache/apk/*

COPY entrypoint.sh setup_user_from_iam.rb assume_role.rb sshd_config $SVC_DIR/
COPY iampubkeys.sh /
RUN chmod 755 /iampubkeys.sh

RUN cat sshd_config >> /etc/ssh/sshd_config

# Make sure we get fresh keys
# Should this be at container start?
RUN rm -rf /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_dsa_key && \
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

ENV BUNDLE_GEMFILE="$SVC_DIR/Gemfile"

# Specify the script to use when running the container
ENTRYPOINT ["entrypoint.sh"]
# Start the main app process by sending the "app" parameter to the entrypoint
CMD ["sshd"]

EXPOSE $SVC_PORT
