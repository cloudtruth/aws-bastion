#!/usr/bin/env bash

# Fail fast
set -e

set -o allexport
source /etc/bastion.env
set +o allexport
export PATH="/sbin:/usr/sbin:$PATH"

ssh_group_arr=($BASTION_SSH_GROUPS)
sudo_group_arr=($BASTION_SUDO_GROUPS)

/usr/local/bin/bundle exec $SVC_DIR/bin/usertool.rb \
  --account "$BASTION_ACCOUNT" \
  --role "$BASTION_ROLE" \
  ssh_keys \
    ${ssh_group_arr[@]/#/--ssh_group } \
    ${sudo_group_arr[@]/#/--sudo_group } \
    --pattern "$BASTION_IAM_USER_PATTERN" \
    "$PAM_USER"

# PAM doesn't recognize newly created account in same request, so the user
# will have to reconnect before they can successfully auth with their key.
