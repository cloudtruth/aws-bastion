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

Setup a docker runtime with the `BASTION_*` environment variables in
`docker-compose.yml`
 * local: docker-compose is already setup to test against a stub aws server (moto),
but you can override the `AWS_*` variables in the environment or a .env file to
run against AWS
 * AWS: Configure your AWS container setup (ECS fargate, EKS, Docker swarm, Custom,
etc) for a bastion service with the `BASTION_*` variables in docker-compose.yml.
Note that your security groups and network settings need to allow the bastion
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

Testing
-------

`docker-compose up -d && docker-compose run dev test`

Security
--------

Use this at your own risk!  I've tried to make this as secure as I know how,
protecting more from external agents than people I trust to manage my
infrastructure.  While I think it is secure enough for the ways in which I use
it, please let me know if it can be improved.