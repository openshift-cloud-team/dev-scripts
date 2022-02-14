# OpenShift hacking tools

## Prerequisites

It's critical to correctly configure the credentials here or the building process will fail with permission errors.

Also, these sets of scripts rely on `podman` as a container engine.
For Mac users podman 3.3+ is required, see [podman machine](https://docs.podman.io/en/latest/markdown/podman-machine.1.html?highlight=machine).

### Accessing registry.ci.openshift.org

For registry.ci.openshift.org, you first need to copy the token from https://oauth-openshift.apps.ci.l2s4.p1.openshiftapps.com/oauth/token/request (top left, "Display Token") and run this command:

```sh
podman login -u <username> -p <token> https://registry.ci.openshift.org
```

### Login into quay.io
This set of scripts assumes that artifacts will be pushed into your personal quay.io registry,
for not facing with auth issues need to log in into quay.io first.
```sh
podman login quay.io
```

### Obtaining OpenShift's quay.io credentials

For OpenShift's quay.io, the credentials need to be taken from https://cloud.redhat.com/openshift/create/local. Click `Download pull secret` and store `pull-secret.txt` in a safe location on your computer.

**NOTE:** These are not your personal credentials, you won't be able to use them to access your personal quay.io account. These credentials are required to obtain the base release image only.

### Limitations
- podman has an issues with mounting volumes on mac platform, see [this issue](https://github.com/containers/podman/issues/8016) for more details.

## Build an operator image with your custom changes

```txt
Usage: ./build_operator_image.sh [options]
Options:
-h, --help        show this message
-o, --operator    operator name to build, examples: machine-config-operator, cluster-kube-controller-manager-operator
-i, --id          id of your pull request to apply on top of the master branch
-u, --username    registered username in quay.io
-t, --tag         push to a custom tag in your origin release image repo, default: latest
-d, --dockerfile  non-default Dockerfile name, default: Dockerfile
```

For instance, if you want to build a Machine Config Operator image with your custom change specified by PR [\#2606](https://github.com/openshift/machine-config-operator/pull/2606) and then push it into your personal quay.io, execute

```sh
$ ./build_operator_image.sh --username johndow --operator machine-config-operator --id 2606
```

**Note**: since Quay doesn't publish images by default, to successfully use the image, you need to make it public manually in the registry web console.

## Build a release image with your custom changes

```txt
Usage: ./build_release_image.sh [options] -u <quay.io username>
Options:
-h, --help     show this message
-u, --username registered username in quay.io
-t, --tag      push to a custom tag in your origin release image repo, default: latest
-r, --release  openshift release version, default: 4.11
-a, --auth     path of registry auth file, default: ./pull-secrets/pull-secret.txt
-i, --image    image(s) to replace in the release payload in the format '<component_name>=<image_path>'
```

To build an actual release image with your custom Machine Config Operator image, that was created in the previous step, execute

```sh
$ ./build_release_image.sh --username johndow --auth ~/pull-secrets/pull-secret.txt -i machine-config-operator=quay.io/johndow/machine-config-operator:latest
```

To replace other component images add more `-i` options (`-i cluster-kube-controller-manager-operator=quay.io/johndow/cluster-kube-controller-manager-operator:latest` for Kube Controller Manager Operator, `-i aws-cloud-controller-manager=quay.io/johndow/aws-cloud-controller-manager:latest` for AWS Cloud Controller manager, and so on). It is possible to replace several images at once.

When the building process is over, the script will upload the release image in your personal quay account, so it can be consumed by the installer.
