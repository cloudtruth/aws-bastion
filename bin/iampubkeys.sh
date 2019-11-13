#!/usr/bin/env bash

# Fail fast
set -e

set -o allexport
source /bastion.env
set +o allexport

ssh_group_arr=($BASTION_SSH_GROUPS)
sudo_group_arr=($BASTION_SUDO_GROUPS)

/usr/local/bin/bundle exec $SVC_DIR/bin/usertool.rb \
  --account "$BASTION_ACCOUNT" \
  --role "$BASTION_ROLE" \
  ssh_keys \
    ${ssh_group_arr[@]/#/--ssh_group } \
    ${sudo_group_arr[@]/#/--sudo_group } \
    --iam_user_pattern "$BASTION_IAM_USER_PATTERN" \
    "$1"
