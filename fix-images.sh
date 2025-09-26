#! /bin/bash

# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# OStree does not handle some types of files very well.  Thankfully
# none of them are especially relevant to the use case of packaging
# container images.  Remove these files.

ROOT="$1"

if [ -z "$ROOT" ]; then
	echo requires root directory
	exit 1
fi

# Get rid of character devices
find "$ROOT" -type c | xargs -r rm

# Get rid of initctl FIFOs
find "$ROOT" -iname initctl | xargs -r rm

# Get rid of backing fs
find "$ROOT" -iname backingFsBlockDev | xargs -r rm
