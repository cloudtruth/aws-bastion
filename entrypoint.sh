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

  sshd)
    bastion_env_file="/bastion.env"
    echo "PATH=$PATH" > $bastion_env_file
    env | grep "^AWS" >> $bastion_env_file
    env | grep "^SVC" >> $bastion_env_file
    env | grep "^BUNDLE" >> $bastion_env_file
    env | grep "^GEM" >> $bastion_env_file
    env | grep "^BASTION" >> $bastion_env_file
    chmod 744 $bastion_env_file
    echo "Starting sshd"
    /usr/sbin/sshd -D -e -p $SVC_PORT
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
