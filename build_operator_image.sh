#!/bin/bash

set -e

help() {
    echo "Build an OpenShift component image with custom changes and upload it to quay.io"
    echo ""
    echo "Usage: ./build_operator_image.sh [options]"
    echo "Options:"
    echo "-h, --help        show this message"
    echo "-a, --auth        path of OCP CI registry auth file, default: ./pull-secrets/pull-secret.txt"
    echo "-o, --operator    operator name to build, examples: machine-config-operator, cluster-kube-controller-manager-operator"
    echo "-i, --id          id of your pull request to apply on top of the master branch"
    echo "-r, --repo-url    repository url for clone"
    echo "-c, --commit      commit hash for clone, repository-url should be provided"
    echo "-u, --username    registered username in quay.io"
    echo "-t, --tag         push to a custom tag in your origin release image repo, default: latest"
    echo "-d, --dockerfile  non-default Dockerfile name, default: Dockerfile"
    echo "--dry-run         if set, build but do not push the image to image registry, default: false"
    echo ""
}

TAG="latest"
DOCKERFILE="Dockerfile"
: ${OC_REGISTRY_AUTH_FILE:=$(pwd)"/pull-secrets/pull-secret.txt"}

# Parse Options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            help
            exit 0
            ;;

        -a|--auth)
            OC_REGISTRY_AUTH_FILE=$2
            shift 2
            ;;

        -u|--username)
            USERNAME=$2
            shift 2
            ;;

        -t|--tag)
            TAG=$2
            shift 2
            ;;

        -o|--operator)
            OPERATOR_NAME=$2
            shift 2
            ;;

        -i|--id)
            PRID=$2
            shift 2
            ;;

        -r|--repo-url)
            CUSTOM_REPO=$2
            shift 2
            ;;

        -c|--commit)
            COMMIT_HASH=$2
            shift 2
            ;;

        -d|--dockerfile)
            DOCKERFILE=$2
            shift 2
            ;;

        --dry-run)
            DRY_RUN=true
            shift
            ;;

        *)
            echo "Invalid option $1"
            help
            exit 0
            ;;
    esac
done

if [ -z "$USERNAME" ]; then
    echo "No quay.io username provided, exiting ..."
    exit 1
fi

if [ -z "$OPERATOR_NAME" ]; then
    echo "No operator name provided, exiting ..."
    exit 1
fi

if [ -n "$PRID" ] && [ -n "$COMMIT_HASH" ]; then
    echo "-c (commit hash) and -i (pr id) options can not be used simultaneously"
    exit 1
fi

OPERATOR_IMAGE=quay.io/$USERNAME/$OPERATOR_NAME:$TAG


if [ -n "$CUSTOM_REPO" ]; then
    GITHUB_REPO="$CUSTOM_REPO"
else
    GITHUB_REPO="https://github.com/openshift/$OPERATOR_NAME"
fi

git ls-remote $GITHUB_REPO 1>/dev/null

echo "Cloning repo $GITHUB_REPO"
rm -rf "build/$OPERATOR_NAME"
git clone $GITHUB_REPO "build/$OPERATOR_NAME"

pushd "build/$OPERATOR_NAME"

if [ -n "$PRID" ]; then
  echo "Applying your changes"
  git fetch origin pull/$PRID/head:$PRID
  git checkout $PRID
  git rebase master
fi

if [ -n "$COMMIT_HASH" ]; then
  echo "Checkoid commit $COMMIT_HASH"
  git checkout $COMMIT_HASH
fi

echo "Setting operator image to $OPERATOR_IMAGE"

echo "Start building operator image"
podman build --no-cache -t $OPERATOR_IMAGE -f $DOCKERFILE .

if [ -z "$DRY_RUN" ]; then
  echo "Pushing operator image to quay.io"
  podman push $OPERATOR_IMAGE
  echo "Successfully pushed $OPERATOR_IMAGE"
else
  echo "Dry run mode is enabled. Do not push $OPERATOR_IMAGE to image registry."
fi

popd

echo "Cleaning up"
rm -rf "build/$OPERATOR_NAME"
