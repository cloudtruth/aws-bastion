FROM ruby:2.6.5 AS base

ARG ADDITIONAL_PACKAGES
ARG PACKAGES="bash tzdata apt-utils openssh-server sudo sshuttle ${ADDITIONAL_PACKAGES}"

ENV SVC_ENV="production" \
    SVC_PORT="2222" \
    SVC_DIR="/srv/app" \
    BUNDLE_PATH="/srv/bundler"

# Thes env var definitions reference values from the previous definitions, so they need to be split off on their own.
# Otherwise, they'll receive stale values because Docker will read the values once before it starts setting values.
ENV BUNDLE_BIN="${BUNDLE_PATH}/bin" \
    GEM_HOME="${BUNDLE_PATH}" \
    PATH="${SVC_DIR}:${BUNDLE_BIN}:${PATH}"

RUN mkdir -p $SVC_DIR $BUNDLE_PATH
WORKDIR $SVC_DIR

COPY Gemfile* $SVC_DIR/

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -q -y $PACKAGES && \
    gem install bundler && \
    bundle install --without="development test" && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/run/sshd
COPY config/sshd.conf /etc/ssh/sshd_config

# remove 'quiet' to see exit codes
RUN sed -i '1 a\auth requisite pam_exec.so quiet log=/var/log/bastion-createuser.log /usr/sbin/iamcreateuser.sh' /etc/pam.d/sshd

# make it easy to tail logs before they get created
RUN touch /var/log/bastion-pubkeys.log /var/log/bastion-createuser.log

# Make sure we get fresh keys
# Should this be at container start?
RUN rm -rf /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_dsa_key && \
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

COPY lib $SVC_DIR/lib/
COPY entrypoint.sh $SVC_DIR/
COPY bin/usertool.rb $SVC_DIR/bin/
COPY bin/iampubkeys.sh /usr/sbin/
COPY bin/iamcreateuser.sh /usr/sbin/
RUN chmod 755 $SVC_DIR/bin/usertool.rb /usr/sbin/iampubkeys.sh /usr/sbin/iamcreateuser.sh

ENV BUNDLE_GEMFILE="$SVC_DIR/Gemfile"

# Specify the script to use when running the container
ENTRYPOINT ["entrypoint.sh"]

FROM base AS production
# Start the main app process by sending the "app" parameter to the entrypoint
CMD ["sshd"]
EXPOSE $SVC_PORT

FROM base AS development
RUN bundle install --with="development test"