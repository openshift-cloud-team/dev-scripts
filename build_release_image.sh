#!/bin/bash

set -e

help() {
    echo "Build a release image with custom OpenShift components and upload it to quay.io"
    echo ""
    echo "Usage: ./build_release_image.sh [options] -u <quay.io username>"
    echo "Options:"
    echo "-h, --help     show this message"
    echo "-u, --username registered username in quay.io"    
    echo "-t, --tag      push to a custom tag in your origin release image repo, default: latest"
    echo "-r, --release  openshift release version, default: 4.10"
    echo "-a, --auth     path of registry auth file, default: ./pull-secrets/pull-secret.txt"
    echo "-i, --image    image(s) to replace in the release payload in the format '<component_name>=<image_path>'"
}

: ${GOPATH:=${HOME}/go}
: ${TAG:="latest"}
: ${RELEASE:="4.10"}
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

        -i|--image)
            IMAGES="${IMAGES} $2"
            shift 2
            ;;

        --release-image)
            FROM_IMAGE=$2
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

echo "Creating local image registry at localhost:5000"
podman rm -fi registry
podman run -d -p 5000:5000 --restart=always --name registry docker.io/library/registry:2

PREFIX="Pull From: "
DEST_IMAGE="quay.io/$USERNAME/origin-release:$TAG"
TEMP_IMAGE="localhost:5000/origin-release:$TAG"

if [ ! -f "$FROM_IMAGE" ]; then
    FROM_IMAGE=$(curl -s  https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp-dev-preview/latest-$RELEASE/release.txt | grep "$PREFIX" | sed -e "s/^$PREFIX//")
fi
echo "Release image: $FROM_IMAGE"
echo "Start building local release image"

oc adm release new \
    --insecure=true \
    --registry-config="$OC_REGISTRY_AUTH_FILE" \
    --from-release="$FROM_IMAGE" \
    --to-image="$TEMP_IMAGE" \
    --server https://api.ci.openshift.org \
    -n openshift \
    ${IMAGES}

echo "The image has been created as $TEMP_IMAGE"

podman pull $TEMP_IMAGE --tls-verify=false

podman image tag $TEMP_IMAGE $DEST_IMAGE

podman push $DEST_IMAGE

echo "Successfully pushed $DEST_IMAGE"

echo "Destroying the local registry"
podman rm -fi registry

echo "Testing release image"
podman pull $DEST_IMAGE
echo "$DEST_IMAGE image was tested, you can now deploy with the following command:"
echo "OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=$DEST_IMAGE openshift-install create cluster (...)"
