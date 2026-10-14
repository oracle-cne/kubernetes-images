#! /bin/bash
#
# Copyright (c) 2026, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Apply the sanity suite's tests/cleanliness/check-base-layer.sh policy to
# the staged RPM payload, without including the build host's images.
set -euxo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	echo "Usage: $0 <rpm-buildroot>" >&2
	exit 1
fi

ROOT=$(realpath "$1")
test -d "$ROOT/usr/ock/containers"
CHECK_STORAGE=$(mktemp -d)
trap 'echo "Removing temporary image-check storage: $CHECK_STORAGE"; rm -rf "$CHECK_STORAGE"' EXIT

# The payload is an additional store, just as on an OCK node. Only metadata
# is inspected; no image layers are mounted and no registry pulls are needed.
PODMAN=(podman --root "$CHECK_STORAGE/storage" --runroot "$CHECK_STORAGE/run"
	--storage-driver overlay --storage-opt "additionalimagestore=$ROOT/usr/ock/containers")

echo "Checking staged image store: $ROOT/usr/ock/containers"
BASE_INSPECT=$("${PODMAN[@]}" image inspect container-registry.oracle.com/os/oraclelinux:8)
BASE_LAYER=$(echo "$BASE_INSPECT" | yq -er '.[].RootFS.Layers[0]')
export BASE_LAYER

IMAGES=$("${PODMAN[@]}" images --format='{{.Repository}}:{{.Tag}}')
test -n "$IMAGES"

for img in $IMAGES; do
	echo "Checking read-only storage and layers for $img"
	[ "$("${PODMAN[@]}" image list --format '{{.ReadOnly}}' "$img" | uniq)" = "true" ]
	INSPECT=$("${PODMAN[@]}" image inspect "$img")

	case "$img" in
	container-registry.oracle.com/olcne/nginx:1.17.7-1 | \
	container-registry.oracle.com/olcne/nginx:1.24.0 | \
	container-registry.oracle.com/olcne/nginx:1.26.3 | \
	container-registry.oracle.com/olcne/pause:3.10 | \
	container-registry.oracle.com/olcne/pause:3.9)
		echo "Checking single-layer exception: $img"
		echo "$INSPECT" | yq -e '.[].RootFS.Layers | length == 1'
		;;
	*)
		echo "Checking at most two layers and shared base layer: $img"
		echo "$INSPECT" | yq -e '.[].RootFS.Layers | length <= 2'
		echo "$INSPECT" | yq -e '.[].RootFS.Layers[0] == strenv(BASE_LAYER)'
		;;
	esac
done

echo "Staged image validation passed"
