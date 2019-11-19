#!/usr/bin/env bash

# fail fast
set -e

function setup_env {
  if [[ -z $AWS_DEFAULT_REGION ]]; then
    export AVAILABILITY_ZONE="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
    export AWS_DEFAULT_REGION="$(echo $AVAILABILITY_ZONE | sed -e 's/[a-z]$//')"
  fi
}
export -f setup_env

action=$1; shift
setup_env

case $action in
  test)
    /usr/local/bin/bundle exec rspec
  ;;

  sshd)
    # sshd runs the AuthorizedKeysCommand in a shell that doesn't inherit the
    # env, so we need to pass it somehow.  iampubkeys.sh sources bastion.env to
    # get it
    bastion_env_file="/etc/bastion.env"
    env | grep "^AWS" > $bastion_env_file
    env | grep "^SVC" >> $bastion_env_file
    env | grep "^BUNDLE" >> $bastion_env_file
    env | grep "^GEM" >> $bastion_env_file
    env | grep "^BASTION" >> $bastion_env_file
    sed -i "s/=\(.*\)/='\1'/g" $bastion_env_file
    chmod 744 $bastion_env_file

    # Pre-create known users so ssh will let them in if they have valid keys
    if [[ $BASTION_FRONTLOAD_USERS == "true" ]]; then
      group_arr=($BASTION_SSH_GROUPS)
      /usr/local/bin/bundle exec $SVC_DIR/bin/usertool.rb \
        --account $BASTION_ACCOUNT --role $BASTION_ROLE \
         create_users \
          ${group_arr[@]/#/--ssh_group } --pattern $BASTION_IAM_USER_PATTERN
    fi

    sshd_cmd="/usr/sbin/sshd -D -e -p $SVC_PORT"
    echo "Starting sshd"

    if [[ "$1" == -d* ]]; then
      # debug mode exits after disconnect
      while true; do $sshd_cmd "$@" || true; done
    else
      $sshd_cmd "$@"
    fi
  ;;

  bash)
    if [ "$#" -eq 0 ]; then
      bash_args=( -il )
    else
      bash_args=( "$@" )
    fi
    exec bash "${bash_args[@]}"
  ;;

  exec)
    exec "$@"
  ;;

  *)
    echo "Unknown action: '$action', defaulting to exec"
    exec $action "$@"
  ;;

esac
