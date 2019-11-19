About
-----

A docker container which provides ssh/vpn by using AWS IAM groups to control
which IAM users can ssh in using the ssh public key stored for those users in
IAM (only they have the private key).  This lets one control ssh/vpn access to a
VPC without having to deal with credentials - you just have to put users in the
right group to enable them to ssh in, and remove them from the group to disable
them, and they have full control over the ssh keypair for authentication

Install
-------

As a convenience, you can use the cloudtruth/aws-bastion image that is built and
pushed to the [docker registry](https://hub.docker.com/r/cloudtruth/aws-bastion)
as part of CI/CD.  You can also build your own image from this repo so as to
customize which system packages get installed to the bastion image.

Setup a docker runtime and configure it with the environment variables:
 * `BASTION_ACCOUNT`: The account to assume role to for looking up iam users and groups
 * `BASTION_ROLE`: The role to assume role to for looking up iam users and groups
 * `BASTION_SSH_GROUPS`: The IAM group to which users will belong to grant them permission to ssh into the bastion
 * `BASTION_SUDO_GROUPS`: The IAM group to which users will belong to grant them permission to sudo on the bastion
 * `BASTION_IAM_USER_PATTERN`: The pattern to use for converting between iam and system username, e.g. "\[user\]@mydomain.com"
 * `BASTION_FRONTLOAD_USERS`:  Causes creation of system users for all known iam users on container start, otherwise done on first connect by that user
 * `AWS_*`: Aws credentials as needed.  You won't need to set them if using instance/ecs roles when running the bastion container

 * local: docker-compose is already setup to test against a stub aws server (moto),
but you can override the `AWS_*` variables in the environment or a .env file to
run against AWS
 * AWS: Configure your AWS container setup (ECS fargate, EKS, Docker swarm, Custom,
etc) for a bastion service with the above environment.  Note that your security groups and network settings need to allow the bastion
host to connect to the internal systems it should have network access to.

Create an IAM group that indicates ssh access to bastion allowed
Create an IAM group that indicates sudo access on the bastion is allowed
Add desired IAM users to the groups for which they should have capabilities

Usage
-----

Run your container
 * local: `docker-compose up`  Note that you'll need to have AWS environment
variables set for the container to be able to query real IAM.  docker-compose is
setup to use moto locally.
 * AWS: `docker-compose build` or plain docker build, then deploy the built image.
 
Each IAM user should add ssh public keys to their IAM user at:
AWS Console -> IAM -> Users -> <their user> -> Security credentials -> Upload SSH public key 

The bastion will authenticate against all active keys set for a user.  The
bastion has a primitive mapping between IAM and system usernames using the
BASTION_IAM_USER_PATTERN environment variable.

SSH to your container
 * Plain ssh: `ssh user@bastion_hostname`
 * SSH with a socks proxy: `ssh -D<local_socks_port> user@bastion_hostname`
 * VPN with [sshuttle](https://sshuttle.readthedocs.io/en/stable/): `sudo sshuttle --dns -r user@bastion_hostname 0/0`

Note that when a user first connects to a new instance of the bastion container,
they get prompted for a password.  Hit enter till it disconnects, then
subsequent connections will succeed with their ssh keys.  If someone has a way
to create a system user that ssh can use as part of the first connection, I
would love to know how.

Testing
-------

`docker-compose up -d && docker-compose run dev test`

Security
--------

Use this at your own risk!  I've tried to make this as secure as I know how,
protecting more from external agents than people I trust to manage my
infrastructure.  While I think it is secure enough for the ways in which I use
it, please let me know if it can be improved.