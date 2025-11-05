#!/bin/bash

if [ "$EUID" -eq 0 ] ; then echo "erro" exit 1 ; fi

mkdir -p caxor

git clone https://github.com/capnproto/capnproto.git caxor/proto2

cmake -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang -G Ninja caxor/proto2/ -B caxor/proto2/build

ninja -C caxor/proto2/build
