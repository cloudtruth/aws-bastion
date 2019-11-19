#!/usr/bin/env bash

# fail fast
set -e

if [[ ! $# -gt 2 ]]; then
  echo "usage: $(basename $0) source_image target_image tag1 [tag2..]"
  exit 1
fi

source_image=$1; shift
target_image=$1; shift
tags="$@"

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

for tag in $tags; do
  target="${target_image}:${tag}"
  echo "Pushing image: '$target'"
  docker tag "$source_image" "$target"
  docker push "$target"
done
