#!/bin/bash

# Get the current user's UID and GID
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Define your Docker image name
IMAGE_NAME="laravel-apps:latest"

# Build the Docker image with the correct user and group IDs
docker build --build-arg USER_ID=$USER_ID --build-arg GROUP_ID=$GROUP_ID -t $IMAGE_NAME .

# Run the Docker container with the same user and group IDs
docker run -d \
    --name laravel-apps \
    --user $USER_ID:$GROUP_ID \
    -v ~/laravel-apps:/var/www/laravel-apps \
    -p 5000:80 \
    $IMAGE_NAME
