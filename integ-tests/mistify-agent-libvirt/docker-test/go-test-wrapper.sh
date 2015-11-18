#!/bin/bash

repo="mistify-agent-libvirt"
ref=${1-master}
echo "Using branch $ref"

die() { echo "$@" 1>&2 ; exit 1; }

echo "Add mistify bridge"
ovs-vsctl --may-exist add-br mistify0
ovs-vsctl show

checkout_dir="$GOPATH/src/github.com/mistifyio/$repo"

cd $GOPATH

echo "Go get dependencies"
go get github.com/kisielk/errcheck
go get github.com/jstemmer/go-junit-report
go get golang.org/x/tools/cmd/goimports
go get github.com/golang/lint/golint
go get -t ./src/github.com/mistifyio/$repo/...

echo "Execute tests"
go test -v -timeout 30s -p 1 ./src/github.com/mistifyio/$repo/...

clone_repo(){
    rm -rf $checkout_dir

    git clone https://github.com/mistifyio/mistify-agent-libvirt $checkout_dir
    if [ $? -gt 0 ]; then
        die "Cloning repo encountered an error."
    fi

    cd $checkout_dir

    echo "Checkout branch"
    git checkout $ref
    if [ $? -ne 0 ]; then
        die "Died trying to checkout the repo on: $ref"
    fi

    git pull
    if [ $? -ne 0 ]; then
        die "Died trying to checkout the repo on: $ref"
    fi
}
