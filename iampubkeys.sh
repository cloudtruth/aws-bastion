#!/usr/bin/env bash

# Fail fast
set -e

set -o allexport
source /bastion.env
set +o allexport

/usr/local/bin/bundle exec $SVC_DIR/setup_user_from_iam.rb \
  --account "$BASTION_ACCOUNT" \
  --role "$BASTION_ROLE" \
  --ssh_group "$BASTION_SSH_GROUP" \
  --sudo_group "$BASTION_SUDO_GROUP" \
  --iam_user_pattern "$BASTION_IAM_USER_PATTERN" \
  "$1"
