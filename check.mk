USER ?= $(shell whoami)
LIBC_I386 := /lib/ld-linux.so.2
GO_VERSION_MAJOR_MIN := 1
GO_VERSION_MINOR_MIN := 13
GO_VERSION_MIN := $(GO_VERSION_MAJOR_MIN).$(GO_VERSION_MINOR_MIN)
SWTPM_VERSION_MAJOR_MIN := 0
SWTPM_VERSION_MINOR_MIN := 6
SWTPM_VERSION_MIN := $(SWTPM_VERSION_MAJOR_MIN).$(SWTPM_VERSION_MINOR_MIN).0

DEBIAN-OS := $(shell [[ -f /etc/os-release ]] && sed -n "s/^ID.*=\(.*\)$$/\1/p" /etc/os-release |grep -q debian;echo y)
HOST-KERNEL := /boot/vmlinuz-$(shell uname -r)
KERNEL-ACCESS := $(shell [[ -r $(HOST-KERNEL) ]] && echo y)

check_bins += go
dep_pkgs += git
check_bins += git
dep_pkgs += pkg-config
check_bins += pkg-config
dep_pkgs += gcc
check_bins += gcc
### linux
check_bins += flex
check_bins += bison
dep_pkgs += libelf-dev
check_libs += libelf
### tboot
dep_pkgs += mercurial
check_bins += hg
dep_pkgs += libtspi-dev
check_libs += trousers
check_trousers_header += trousers/tss.h
### stboot-installation
check_bins += jq
dep_pkgs += e2tools
check_bins += e2mkdir
dep_pkgs += mtools
check_bins += mmd
## mbr bootloader installation
dep_pkgs += libc6-i386
### debos
## native env
ifeq ($(DEBIAN-OS),y)
dep_pkgs += libglib2.0-dev
check_debos_libs += glib-2.0
check_libs += gobject-2.0
dep_pkgs += libostree-dev
check_libs += ostree-1
check_bins += debootstrap
endif
dep_pkgs += systemd-container
check_bins += systemd-nspawn
## docker env
check_bins += docker
## podman env
#check_bins += podman
### qemu test
dep_pkgs += qemu-kvm
# swtpm(https://github.com/stefanberger/swtpm)
check_bins += swtpm
check_bins += swtpm_cert
check_bins += swtpm_setup
# swtpm deps:
#libtpms(https://github.com/stefanberger/libtpms)
dep_pkgs += autoconf
dep_pkgs += libtool
dep_pkgs += libtasn1-6-dev
dep_pkgs += libgnutls28-dev
dep_pkgs += expect
dep_pkgs += gawk
dep_pkgs += socat
dep_pkgs += python3-pip
dep_pkgs += gnutls-bin
dep_pkgs += libseccomp-dev

ifeq ($(findstring check,$(MAKECMDGOALS)),)
CHECK_ERROR := ERROR
CHECK_EXIT := kill -TERM $(MAKEPID);
else
CHECK_ERROR := WARN
endif

ifeq ($(DEBIAN-OS),y)
install-deps:
	if [ "$(shell id -u)" -ne 0 ]; then \
	  $(call LOG,ERROR,Please run as root); \
	  kill -TERM $(MAKEPID); \
	fi;
	$(call LOG,INFO,Install dependencies:,$(dep_pkgs))
	apt-get update -yqq
	apt-get install -yqq --no-install-recommends $(dep_pkgs)
	$(call LOG,DONE,dependencies installed)
endif

check_targets += $(foreach bin,$(check_bins),check_$(bin)_bin)
check_%_bin:
	@$(call LOG,INFO,Check command:,$*)
	if CMD=$$(command -v "$*" 2>/dev/null); then \
	  $(call LOG,OK,command found:,$${CMD});\
	else \
	  $(call LOG,$(CHECK_ERROR),command not found:,$*);\
	  $(CHECK_EXIT) \
	fi;

check_targets += check_go_bin_version
check_go_bin_version: check_go_bin
	$(eval GO_VERSION := $(shell go version 2>/dev/null | sed -nr 's/.*go([0-9]+\.[0-9]+.?[0-9]?).*/\1/p'))
	$(eval GO_VERSION_MAJOR := $(shell echo $(GO_VERSION) | cut -d . -f 1)) \
	$(eval GO_VERSION_MINOR := $(shell echo $(GO_VERSION) | cut -d . -f 2)) \
	if command -v "go" >/dev/null 2>&1; then \
	  $(call LOG,INFO,Check Go version); \
	  if [ "$(GO_VERSION_MAJOR)" -gt "$(GO_VERSION_MAJOR_MIN)" ] || \
	  ([ "$(GO_VERSION_MAJOR)" -eq "$(GO_VERSION_MAJOR_MIN)" ] && \
	  [ "$(GO_VERSION_MINOR)" -ge "$(GO_VERSION_MINOR_MIN)" ]); then \
	    $(call LOG,OK,Go version \"$(GO_VERSION)\" supported); \
	  else \
	    $(call LOG,$(CHECK_ERROR),Go version \"$(GO_VERSION)\" is not supported); \
	    $(call LOG,$(CHECK_ERROR),Needs version \"$(GO_VERSION_MIN)\" or later.); \
	    $(CHECK_EXIT) \
	  fi; \
	fi;

check_targets += check_swtpm_bin_version
check_swtpm_bin_version: check_swtpm_bin
	$(eval SWTPM_VERSION := $(shell swtpm --version 2>/dev/null | cut -d ' ' -f 4 | sed 's/,//'))
	$(eval SWTPM_VERSION_MAJOR := $(shell echo $(SWTPM_VERSION) | cut -d . -f 1))
	$(eval SWTPM_VERSION_MINOR := $(shell echo $(SWTPM_VERSION) | cut -d . -f 2))
	if command -v "swtpm" >/dev/null 2>&1; then \
	  $(call LOG,INFO,Check swtpm version); \
	  if [ "$(SWTPM_VERSION_MAJOR)" -gt "$(SWTPM_VERSION_MAJOR_MIN)" ] || \
	  ([ "$(SWTPM_VERSION_MAJOR)" -eq "$(SWTPM_VERSION_MAJOR_MIN)" ] && \
	  [ "$(SWTPM_VERSION_MINOR)" -ge "$(SWTPM_VERSION_MINOR_MIN)" ]); then \
	    $(call LOG,OK,swtpm version \"$(SWTPM_VERSION)\" supported); \
	  else \
	    $(call LOG,$(CHECK_ERROR),swtpm version \"$(SWTPM_VERSION)\" is not supported); \
	    $(call LOG,$(CHECK_ERROR),Needs version \"$(SWTPM_VERSION_MIN)\" or later.); \
	    $(CHECK_EXIT) \
	  fi; \
	fi;


check_targets += $(foreach lib,$(check_libs),check_$(lib)_lib)
check_%_lib:
	$(call LOG,INFO,Check library:,$*)
	if [ -z "$(check_$*_header)" ]; then \
	  if command -v "pkg-config" >/dev/null 2>&1; then \
	    if pkg-config "$*" >/dev/null 2>&1; then \
	      $(call LOG,OK,library found:,$*);\
	    else \
	      $(call LOG,$(CHECK_ERROR),library not found:,$*); \
	      $(CHECK_EXIT) \
	    fi; \
	  else \
	    $(call LOG,$(CHECK_ERROR),\"pkg-config\" required to check library:,$*); \
	    $(CHECK_EXIT) \
	  fi; \
	else \
	  $(call LOG,INFO,Lookup \"$*\" library header:,$(check_$*_header)); \
	  if (printf "#include <$(check_$*_header)>\n" | gcc -x c - -Wl,--defsym=main=0 -o /dev/null >/dev/null 2>&1); then \
	    $(call LOG,OK,library found:,$*); \
	  else \
	    $(call LOG,$(CHECK_ERROR),library header not found:,$(check_$*_header)); \
	    $(CHECK_EXIT) \
	  fi; \
	fi;

check_targets += check_libc_i386
check_libc_i386:
	@$(call LOG,INFO,Check runtime library:,libc(i386)) 
	if [[ ! -f "$(LIBC_I386)" ]];then \
	    $(call LOG,$(CHECK_ERROR),runtime library not found:,$(LIBC_I386)); \
	    $(call LOG,$(CHECK_ERROR),Install libc runtime library for i368); \
	    $(CHECK_EXIT) \
	else \
	    $(call LOG,OK,runtime library found:,libc(i386)); \
	fi;

check_targets += check_debos_native
check_debos_native:
	@$(call LOG,INFO,Check if OS is debian based)
	if ([[ -f /etc/os-release ]] && sed -n "s/^ID.*=\(.*\)$$/\1/p" /etc/os-release |grep -q debian); then \
	  $(call LOG,OK,OS is debian based. native debos build environment is supported.); \
	else \
	  $(call LOG,$(CHECK_ERROR),OS is not debian based.); \
	  $(call LOG,$(CHECK_ERROR),native debos build environment is not supported.); \
	fi;
	  
check_targets += check_debos_docker
check_debos_docker: check_docker_bin
	if command -v "docker" >/dev/null 2>&1; then \
	  if docker info >/dev/null 2>&1; then \
	    $(call LOG,OK,Access to docker API granted. docker debos build environment is supported.); \
	  else \
	    $(call LOG,$(CHECK_ERROR),No access to docker API); \
	    $(call LOG,$(CHECK_ERROR),Add user \"$(USER)\" to the docker group); \
	    $(call LOG,$(CHECK_ERROR),docker debos build environment is not supported); \
	    $(CHECK_EXIT) \
	  fi; \
	else \
	  $(call LOG,$(CHECK_ERROR),install docker to enable docker debos build environment.);\
	  $(CHECK_EXIT) \
	fi;

check_targets += check_kvm
check_kvm:
	@$(call LOG,INFO,Check for kvm virtualisation accessibility)
	if [[ -c /dev/kvm ]]; then \
	  $(call LOG,OK,/dev/kvm device available); \
	else \
	  $(call LOG,$(CHECK_ERROR),/dev/kvm device not available); \
	  if (cat /proc/cpuinfo |grep -q hypervisor); then \
	    $(call LOG,INFO,hypervisor virtualized environment detected:); \
	    $(call LOG,$(CHECK_ERROR),enable nested kvm virtualisation on your host); \
	  else \
	    $(call LOG,INFO,bare-metal environment detected:); \
	    $(call LOG,$(CHECK_ERROR),enable virtualisation on your host); \
	  fi; \
	  $(CHECK_EXIT) \
	fi;

check_targets += check_kvm_access
check_kvm_access: check_kvm
	if [[ -c /dev/kvm ]]; then \
	  $(call LOG,INFO, Check /dev/kvm device writeability); \
	  if [[ -w /dev/kvm ]]; then \
	    $(call LOG,OK,/dev/kvm is writable by user \"$(USER)\"); \
	  else \
	    $(call LOG,$(CHECK_ERROR),/dev/kvm is not writable by user \"$(USER)\"); \
	    $(call LOG,$(CHECK_ERROR),Install \"qemu-kvm\" and add user \"$(USER)\" to the kvm group); \
	    $(CHECK_EXIT) \
	  fi; \
	fi;

check: $(check_targets)

.PHONY: install-deps check check_%
