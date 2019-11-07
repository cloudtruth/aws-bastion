#!/usr/bin/env bash

# Fail fast
set -e

EX_TEMPFAIL=75
EX_NOPERM=77

echo "Starting $0"

# If system user exists
if getent passwd "$PAM_USER" >/dev/null 2>&1; then
  # Fail as one only gets here if the user hasn't setup a public key
  echo "User already exists"
  exit $EX_NOPERM
else
  # Otherwise create the user, then halt PAM. The SSH client will fail, and the user will need to try again.
  # Verify that the IAM user exists.
  set -o allexport
  source /bastion.env
  set +o allexport

  /usr/local/bin/bundle exec $SVC_DIR/setup_user_from_iam.rb \
    --account "$BASTION_ACCOUNT" \
    --role "$BASTION_ROLE" \
    --ssh_group "$BASTION_SSH_GROUP" \
    --sudo_group "$BASTION_SUDO_GROUP" \
    --iam_user_pattern "$BASTION_IAM_USER_PATTERN" \
    "$PAM_USER" #> /dev/null #stdout is just keys, logging on stderr
    echo "User created successfully"
    exit $EX_TEMPFAIL
fi
