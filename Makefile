# Makefile to build and release "crun", "libkrun", and "libkrunfw"
#
# Usage:
#   make        - Build and release the components.
#   make clean  - Clean the build directories.
#
# Verbosity:
#   Set V=1 for verbose output.
#
# Dependencies:
# 	"apt" and "curl" should be installed.

SHELL = /bin/bash
APT   = $(shell command -v apt-get)
CURL  = $(shell command -v curl)
TAR   = $(shell command -v tar)
MAKE  = $(shell command -v make)

ARCH  = $(shell uname -m)
PATH  := $(HOME)/.cargo/bin:$(PATH)

CRUN_VERSION      = 1.15
LIBKRUN_VERSION   = 1.9.3
LIBKRUNFW_VERSION = 4.0.0

CRUN_CONF_FLAGS = --enable-embedded-yajl --with-libkrun
CRUN_BUILD_PATH = crun/crun

BIN_CRUN       = $(CRUN_BUILD_PATH)-$(CRUN_VERSION)
LIB_LIBKRUN    = libkrun/target/release/libkrun.so.$(LIBKRUN_VERSION)
LIB_LIBKRUNFW  = libkrunfw/libkrunfw.so.$(LIBKRUNFW_VERSION)

RELEASE_PFX = release-$(ARCH)
RELEASE_TAR = $(RELEASE_PFX).tar.gz
RELEASE_SUM = $(RELEASE_PFX).sha1

PATCHELF_VERSION = 0.18.0
PATCHELF_BIN     = patchelf
PATCHELF_REPO    = https://github.com/NixOS/patchelf
PATCHELF_REL     = $(PATCHELF_REPO)/releases/download/$(PATCHELF_VERSION)
PATCHELF_TGZ     = $(PATCHELF_BIN)-$(PATCHELF_REL)-$(ARCH).tar.gz

DEPS = autoconf automake bc bison build-essential curl elfutils flex \
       gcc git go-md2man libcap-dev libelf-dev libprotobuf-c-dev     \
       libseccomp-dev libsystemd-dev libtool libyajl-dev make patch  \
       pkgconf python3 python3-pyelftools

# For verbosity.
ifeq ($(V),1)
Q =
msg =
APT_FLAGS = -y
APT_QUIET =
else
Q = @
APT_FLAGS = -qq -o=Dpkg::Use-Pty=0
APT_QUIET = < /dev/null > /dev/null
msg = @printf '  %-8s %s%s\n' "$(1)" "$(2)" "$(if $(3), $(3))";
MAKEFLAGS += --no-print-directory
endif

default: $(RELEASE_PFX)

$(RELEASE_PFX): crun
	$(call msg,"RELEASE")
	$(Q)mkdir -p $(RELEASE_PFX)

	$(Q)cp $(BIN_CRUN) $(LIB_LIBKRUN) $(LIB_LIBKRUNFW) $(RELEASE_PFX)
	$(Q)$(TAR) -czf $(RELEASE_TAR) $(RELEASE_PFX)
	$(Q)sha1sum --binary $(RELEASE_TAR) >$(RELEASE_SUM)

	$(Q)rm -rf $(RELEASE_PFX)

crun: libkrun
	$(call msg,"CRUN")
	$(Q)pushd crun && ./autogen.sh && ./configure $(CRUN_CONF_FLAGS) && popd
	$(Q)$(MAKE) -C crun
	$(Q)mv $(CRUN_BUILD_PATH) $(BIN_CRUN)


libkrun: libkrunfw
	$(call msg,"LIBKRUN")
	$(Q)$(MAKE) BLK=1 NET=1 TIMESYNC=1 -C libkrun
	$(Q)$(MAKE) -C libkrun install

libkrunfw: deps
	$(call msg,"LIBKRUNFW")
	$(Q)$(MAKE) -C libkrunfw
	$(Q)$(MAKE) -C libkrunfw install

deps: rust patchelf
	$(call msg,"DEPS")
	$(Q)$(APT) $(APT_FLAGS) update $(APT_QUIET)
	$(Q)$(APT) $(APT_FLAGS) install $(DEPS) $(APT_QUIET)

rust:
	$(call msg,"RUST")
	$(Q)$(CURL) -fSsL https://sh.rustup.rs | $(SHELL) -s -- -y &>/dev/null

patchelf:
	$(call msg,"PATCHELF")
	$(Q)$(CURL) -fsSLO "$(PATCHELF_REL)/$(PATCHELF_TGZ)"
	$(Q)$(TAR) --strip-components=2 -xzvf $(PATCHELF_TGZ) ./bin/$(PATCHELF_BIN)
	$(Q)mv $(PATCHELF_BIN) /usr/local/bin

clean:
	$(Q)$(MAKE) -C crun clean
	$(Q)$(MAKE) -C libkrun clean
	$(Q)$(MAKE) -C libkrunfw clean

.PHONY: default crun libkrun libkrunfw clean
.DELETE_ON_ERROR:
.NOTPARALLEL:
