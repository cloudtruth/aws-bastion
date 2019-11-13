Install
-----

Setup a docker runtime with the variables in .env
 * local: Edit .env and set the values.  You'll probably want to `git update-index --skip-worktree .env` to prevent git from seeing it as dirty due to your edits
 * AWS: Configure your AWS container setup (ECS fargate, EKS, Docker swarm, Custom, etc) for a bastion service with the variables in .env.  Note that your security groups and network settings need to allow the bastion host to connect to the internal systems it should have network access to.

Create an IAM group that indicates ssh access to bastion allowed
Create an IAM group that indicates sudo access on the bastion is allowed
Add desired IAM users to the groups for which they should have capabilities

Usage
-----

Run your container
 * local: `docker-compose up`  Note that you'll need to have AWS environment variables set for the container to be able to query IAM.  docker-compose is setup to pass through the common ones from the terminal you run docker-compose from 
 * AWS: `docker-compose build` or plain docker build, then deploy the built image.
 
Each IAM user should add ssh public keys to their IAM user.  The bastion will authenticate against all active keys:
AWS Console -> IAM -> Users -> <their user> -> Security credentials -> Upload SSH public key 

SSH to your container
 * Plain ssh: `ssh user@bastion_hostname`
 * SSH with a socks proxy: `ssh -D<local_socks_port> user@bastion_hostname`
 * VPN with sshuttle: `sudo sshuttle --dns -r user@bastion_hostname 0/0`
