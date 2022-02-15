#!/bin/bash

set -e

help() {
    echo "Build a release image with specific changes to enable cluster API provider and upload it to quay.io"
    echo ""
    echo "Usage: ./build_capi_release.sh [options] -u <quay.io username>"
    echo "Options:"
    echo "-h, --help      show this message"
    echo "-u, --username  registered username in quay.io"
    echo "-t, --tag       push to a custom tag in your origin release image repo, default: latest"
    echo "-r, --release   openshift release version, default: 4.11"
    echo "-a, --auth      path of registry auth file, default: ./pull-secrets/pull-secret.txt"
}

: ${TAG:="latest"}
: ${RELEASE:="4.9"}
: ${OC_REGISTRY_AUTH_FILE:=$(pwd)"/pull-secrets/pull-secret.txt"}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            help
            exit 0
            ;;

        -u|--username)
            USERNAME=$2
            shift 2
            ;;

        -t|--tag)
            TAG=$2
            shift 2
            ;;

        -r|--release)
            RELEASE=$2
            shift 2
            ;;

        -a|--auth)
            OC_REGISTRY_AUTH_FILE=$2
            shift 2
            ;;

        *)
            echo "Invalid option $1"
            help
            exit 1
            ;;
    esac
done

if [ -z "$USERNAME" ]; then
    echo "-u/--username was not provided, exiting ..."
    exit 1
fi

if [ ! -f "$OC_REGISTRY_AUTH_FILE" ]; then
    echo "$OC_REGISTRY_AUTH_FILE not found, exiting ..."
    exit 1
fi

echo "Building and uploading a custom image for CAPIO"
./build_operator_image.sh -u "$USERNAME" -o cluster-capi-operator -d Dockerfile.rhel -t "$TAG"

echo "Building a release image"
./build_release_image.sh -u "$USERNAME" -a "$OC_REGISTRY_AUTH_FILE" \
    -i cluster-capi-operator=quay.io/"$USERNAME"/cluster-capi-operator:"$TAG"
