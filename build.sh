#!/bin/sh
# tl - build script
# see LICENSE for copyright and license details.

die() {
	printf "error: %s\n" "$1" >&2
	exit 1
}

check_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "$1 not found"
}

check_pkg() {
	pkg-config --exists "$1" 2>/dev/null || die "$1 not found (install lib$1-dev or equivalent)"
}

check_cmd nim
check_cmd pkg-config

if ! nimble path x11 >/dev/null 2>&1; then
	printf "x11 nim package not found, installing...\n"
	check_cmd nimble
	nimble install x11 -y || die "failed to install x11 nim package"
fi

check_pkg x11
check_pkg xft
check_pkg freetype2
check_pkg fontconfig

CFLAGS="-O2 -march=native"
LDFLAGS="$(pkg-config --libs x11 xft freetype2 fontconfig)"

printf "building tl...\n"

nim c \
	-d:release \
	--opt:size \
	--passC:"$CFLAGS" \
	--passL:"$LDFLAGS" \
	tl.nim || die "build failed"

printf "done. run ./tl\n"
