#!/bin/bash
# List container to keep
container_keep_id=$(docker ps -q --filter "name=ceph-*" | tr '\n' ' ' | xargs echo)
# Containers to keep (separated by spaces)
containers_to_keep="$container_keep_id"


# Remove all containers that are not in the list of containers to keep
for container in $(docker ps -aq --no-trunc); do
    if [[ " $containers_to_keep " != *" $container "* ]]; then
        docker rm -f $container
    fi
done

# Remove all images that don't have any tags and are not related to a container to keep
for image in $(docker images -q --filter "dangling=true"); do
    if ! docker ps --filter "ancestor=$image" --no-trunc -q | grep -qwE "$(echo $containers_to_keep | sed 's/ /|/g')"; then
        docker rmi -f $image
    fi
done

# Remove all volumes that are not related to a container to keep
for volume in $(docker volume ls --format "{{.Name}}"); do
    if ! docker ps --filter "volume=$volume" --no-trunc -q | grep -qwE "$(echo $containers_to_keep | sed 's/ /|/g')"; then
        docker volume rm $volume
    fi
done

# Remove all networks that are not related to a container to keep
for network in $(docker network ls --format "{{.Name}}"); do
    if ! docker network inspect $network | grep -qwE "$(echo $containers_to_keep | sed 's/ /|/g')"; then
        docker network rm $network
    fi
done
