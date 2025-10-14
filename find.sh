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
