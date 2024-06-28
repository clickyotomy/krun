SHELL = /bin/bash
APT   = $(shell command -v apt-get)
CURL  = $(shell command -v curl)
ARCH  = $(shell uname -m)
PATH  := $(HOME)/.cargo/bin:$(PATH)

CRUN_VERSION      = 1.15
LIBKRUN_VERSION   = 1.9.3
LIBKRUNFW_VERSION = 4.0.0

BIN_CRUN      = crun/crun
LIB_LIBKRUN   = libkrun/target/release/libkrun.so.$(LIBKRUN_VERSION)
LIB_LIBKRUNFW = libkrunfw/libkrunfw.so.$(LIBKRUNFW_VERSION)

RELEASE_DIR = release
RELEASE_TAR = release-$(CRUN_VERSION)-$(ARCH).tar.gz
RELEASE_SUM = release-$(CRUN_VERSION)-$(ARCH).sha1

DEPS = autoconf automake bc bison build-essential curl elfutils flex \
       gcc git go-md2man libcap-dev libelf-dev libprotobuf-c-dev     \
       libseccomp-dev libsystemd-dev libtool libyajl-dev make patch  \
       patchelf pkgconf python3 python3-pyelftools



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

default: $(RELEASE_DIR)

$(RELEASE_DIR): crun
	$(Q)mkdir -p $(RELEASE_DIR)
	$(Q)cp $(BIN_CRUN) $(LIB_LIBKRUN) $(LIB_LIBKRUNFW) $(RELEASE_DIR)
	$(Q)tar -czf $(RELEASE_TAR) $(RELEASE_DIR)
	$(Q)sha1sum --binary $(RELEASE_TAR) >$(RELEASE_SUM)
	$(Q)rm -rf $(RELEASE_DIR)

crun: libkrun
	$(call msg,"CRUN")
	$(Q)pushd crun && ./autogen.sh && ./configure --with-libkrun && popd
	$(Q)make -C crun

libkrun: libkrunfw
	$(call msg,"LIBKRUN")
	$(Q)make BLK=1 NET=1 TIMESYNC=1 -C libkrun
	$(Q)make -C libkrun install

libkrunfw: deps
	$(call msg,"LIBKRUNFW")
	$(Q)make -C libkrunfw
	$(Q)make -C libkrunfw install

deps: rust
	$(call msg,"DEPS")
	$(Q)$(APT) $(APT_FLAGS) update $(APT_QUIET)
	$(Q)$(APT) $(APT_FLAGS) install $(DEPS) $(APT_QUIET)

rust:
	$(call msg,"RUST")
	$(Q)$(CURL) -fSsL https://sh.rustup.rs | $(SHELL) -s -- -y &>/dev/null

clean:
	$(Q)make -C crun clean
	$(Q)make -C libkrun clean
	$(Q)make -C libkrunfw clean

.PHONY: default crun libkrun libkrunfw clean
.DELETE_ON_ERROR:
.NOTPARALLEL:
