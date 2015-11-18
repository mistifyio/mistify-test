#!/bin/bash

repo="mistify-agent-libvirt"

die() { echo "$@" 1>&2 ; exit 1; }

echo "Add mistify bridge"
/add-mistify-bridge.sh
ovs-vsctl show || die "Failed running ovs-vsctl"

checkout_dir="$GOPATH/src/github.com/mistifyio/$repo"

cd $GOPATH

echo "Go get dependencies"
go get -t ./src/github.com/mistifyio/$repo/... || die "Failed downloading dependencies"

echo "Execute tests"
go test -v -timeout 30s -p 1 ./src/github.com/mistifyio/$repo/... || die "Failed executing tests"