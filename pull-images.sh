#! /bin/bash

# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

IMAGE=container-registry.oracle.com/os/oraclelinux:8

KUBE=
PAUSE=
ETCD=
COREDNS=
FLANNEL=
UI=
UI_PLUGINS=
CATALOG=
NGINX=
BASE_IMAGE=

while true; do
	case "$1" in
	"") break;;
	--kube-tag ) KUBE="$2"; shift; shift ;;
	--pause-tag ) PAUSE="$2"; shift; shift ;;
	--etcd-tag ) ETCD="$2"; shift; shift ;;
	--coredns-tag ) COREDNS="$2"; shift; shift ;;
	--flannel-tag ) FLANNEL="$2"; shift; shift ;;
	--ui-tag ) UI="$2"; shift; shift ;;
	--plugins-tag ) UI_PLUGINS="$2"; shift; shift ;;
	--catalog-tag ) CATALOG="$2"; shift; shift ;;
	--nginx-tag ) NGINX="$2"; shift; shift ;;
	--base-image ) BASE_IMAGE="$2"; shift; shift ;;
	--base ) BASE="$2"; shift; shift ;;
	--root ) ROOT="$2"; shift; shift ;;
	--archive ) ARCHIVES="$2"; shift; shift ;;
	*) exit 1;;
	esac
done

set -e

# It is necessary to trick the container image database when
# pulling to an alternate location.  The database and manifests
# get translated to absolute paths.  If the pull is to some directory
# in a local folder, the paths in that folder are preserved.  This
# is not what is wanted when building an OS image.
#
# To trick it, podman is used to create a container, which in turns uses
# podman to pull images.  A volume is mounted at the right spot in the
# container so that the paths all make sense after the fact.
BASE=$(realpath "$BASE")
FULL_PATH="$BASE/$ROOT"

OCR="container-registry.oracle.com/olcne"

podman pull "${BASE_IMAGE}"
podman save "${BASE_IMAGE}" > "$ARCHIVES/base.tar"

# When podman/cri-o store container images on-disk, the layer database points to
# absolute paths rather than relative ones.  As a consequence, any pulls to a
# path must actually be pulled to that path.  This is why the pulls are done in
# a container.  That way, images can be pulled to the correct path without having
# to worry about privilege or tainting the build system.
#
# Notice the way that nginx is handled.  Unlinke the other images packaged here,
# nginx can be used as a base image for a variety of legitimate use cases.
# Using the same base layer as the other images defeats the purpose of that
# base image because there is a good chance that some applications will use
# it as a base layer as a consequence of having nginx as a base layer.  To
# avoid that from happening, the nginx container image gets rebuilt and
# squashed so that it has a unique SHA that is never available in a container
# registry.

podman run --privileged --security-opt label=disable --rm -i -v /etc/containers:/etc/containers-host -v "$FULL_PATH:$ROOT" -v "$ARCHIVES:/archives" "$IMAGE" sh << EOF
set -e
set -x
dnf install -y podman

cp /etc/containers-host/registries.conf.d/* /etc/containers/registries.conf.d/

printf "FROM $OCR/nginx:${NGINX}-orig\nWORKDIR /etc/nginx\n" > Dockerfile.nginx

podman load --root="${ROOT}" < "/archives/base.tar"
podman tag --root="${ROOT}" "${BASE_IMAGE}" "container-registry.oracle.com/os/oraclelinux:8"
podman rmi --root="${ROOT}" "${BASE_IMAGE}"
podman pull --root="${ROOT}" $OCR/kube-apiserver:${KUBE}
podman pull --root="${ROOT}" $OCR/kube-proxy:${KUBE}
podman pull --root="${ROOT}" $OCR/kube-controller-manager:${KUBE}
podman pull --root="${ROOT}" $OCR/kube-scheduler:${KUBE}
podman pull --root="${ROOT}" $OCR/pause:${PAUSE}
podman pull --root="${ROOT}" $OCR/etcd:${ETCD}
podman pull --root="${ROOT}" $OCR/coredns:${COREDNS}
podman pull --root="${ROOT}" $OCR/flannel:${FLANNEL}
podman pull --root="${ROOT}" $OCR/ui:${UI}
podman pull --root="${ROOT}" $OCR/ui-plugins:${UI_PLUGINS}
podman pull --root="${ROOT}" $OCR/ocne-catalog:${CATALOG}
podman pull --root="${ROOT}" $OCR/nginx:${NGINX}

podman tag --root="${ROOT}" $OCR/nginx:${NGINX} $OCR/nginx:${NGINX}-orig
podman rmi --root="${ROOT}" $OCR/nginx:${NGINX}
podman build --root="${ROOT}" --squash-all --pull=never --tag $OCR/nginx:${NGINX} --file Dockerfile.nginx .
podman rmi --root="${ROOT}" $OCR/nginx:${NGINX}-orig

podman tag --root="${ROOT}" ${OCR}/kube-proxy:${KUBE} ${OCR}/kube-proxy:current
podman tag --root="${ROOT}" ${OCR}/coredns:${COREDNS} ${OCR}/coredns:current
podman tag --root="${ROOT}" $OCR/ui:${UI} $OCR/ui:current
podman tag --root="${ROOT}" $OCR/flannel:${FLANNEL} $OCR/flannel:current
EOF

# Make a catalog of images so it's easy to tell which are encoded in this
# layer.  The motiviation behind doing this is that it facilitates
# upgrades from one version to the next.
cat > "$(dirname $FULL_PATH)/catalog.yaml" << EOF
kubeApiServer: ${OCR}/kube-apiserver:${KUBE}
kubeControllerManager: ${OCR}/kube-controller-manager:${KUBE}
kubeScheduler: ${OCR}/kube-scheduler:${KUBE}
etcd: ${OCR}/etcd:${ETCD}
nginx: ${OCR}/nginx:${NGINX}
EOF

# Make a set of patches that get applied during kubeadm init/join that force
# the static manifests to these images.
mkdir -p "$(dirname $FULL_PATH)/patches"
PATCH='[{"op": "replace", "path": "/spec/containers/0/image", "value": "%b"}]'
printf "$PATCH" ${OCR}/etcd:${ETCD} > "$(dirname $FULL_PATH)/patches/etcd+json.json"
for k in kube-apiserver kube-proxy kube-controller-manager kube-scheduler; do
	printf "$PATCH" ${OCR}/${k}:${KUBE} > "$(dirname $FULL_PATH)/patches/${k}+json.json"
done

