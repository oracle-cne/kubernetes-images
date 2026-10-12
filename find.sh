#! /bin/bash
#
# Copyright (c) 2025, Oracle and/or its affiliates. All rights reserved.

KUBE_VERSION="$1"

REGISTRY="container-registry.oracle.com/olcne"
if [ -n "$2" ]; then
	REGISTRY="$2"
fi

echo "Searcing $REGISTRY"

imgs="kube-apiserver pause etcd coredns flannel ui ui-plugins ocne-catalog nginx"

declare -A imgMap
imgMap['pause']="pause"
imgMap['etcd']="etcd"
imgMap['coredns']="coredns"
imgMap['flannel']="flannel"
imgMap['ui']="ui_tag"
imgMap['ui-plugins']="ui_plugins"
imgMap['ocne-catalog']="catalog"
imgMap['nginx']="nginx"

declare -A tagMap

for shortImg in $imgs; do
	img="${REGISTRY}/${shortImg}"
	echo "Checking $img"
	TAGS=$(skopeo list-tags "docker://${img}" | jq -r '.Tags[]' | grep -v -e '-[a-z][a-z0-9]*')

	if [ "$img" == "${REGISTRY}/kube-apiserver" ]; then
		TAGS=$(echo "$TAGS" | grep "$KUBE_VERSION")
	fi
	if [ "$shortImg" == "etcd" ]; then
		echo "Comparing Kubernetes $KUBE_VERSION with the etcd 3.5 cutoff 1.34 using version sort"
		if [ "$(printf '%s\n' "$KUBE_VERSION" '1.34' | sort -V | head -1)" != '1.34' ]; then
			echo "Kubernetes $KUBE_VERSION requires etcd 3.5; filtering published tags before version selection"
			TAGS=$(echo "$TAGS" | grep -E '^3\.5\.[0-9]+(-[0-9]+)?$')
			if [ -z "$TAGS" ]; then
				echo "No published etcd 3.5 tag is available for Kubernetes $KUBE_VERSION; discovery failed" >&2
				exit 1
			fi
		else
			echo "Kubernetes $KUBE_VERSION does not require the etcd 3.5 filter; selecting from published tags"
		fi
	fi
	if [ "$shortImg" == "ui" ]; then
		TAGS=$(echo "$TAGS" | grep -vxF "v2.0.0")
	fi
	TAGS=$(echo "$TAGS" | sort -Vr)

	TAG=$(echo "$TAGS" | head -1)
	echo "$TAG"
	tagMap["$shortImg"]="$TAG"
done

echo "---------Replace Empty Variables------------"

suffix=
for shortImg in $imgs; do
	TAG="${tagMap[${shortImg}]}"
	if [ "$shortImg" == "kube-apiserver" ]; then
		maj=$(echo "$TAG" | cut -d. -f 1 | tr -d 'v')
		min=$(echo "$TAG" | cut -d. -f 2)
		pat=$(echo "$TAG" | cut -d. -f 3 | grep -o '^[0-9]*')
		suffix=$(echo "$TAG" | cut -d. -f 3 | grep -o -e '-[0-9]*$')
		echo "String verion = \"${maj}.${min}\""
		echo "String patch = \"${pat}\""
		echo
		continue
	fi

	VAR="${imgMap[${shortImg}]}"
	echo "String ${VAR} = \"$TAG\""
done


if [ -n "$suffix" ]; then
	echo "-------Replace Map Entry----------"
	echo "    \"\${reg}/kube-apiserver:v\${version}.\${patch}${suffix}\","
fi
