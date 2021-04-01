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
### linux
check_bins += curl
check_bins += flex
check_bins += bison
# libelf-dev
check_libs += libelf
### tboot
# mercurial
check_bins += hg
# libtspi-dev
check_libs += trousers
check_trousers_header += trousers/tss.h
### stboot-installation
check_bins += jq
# e2tools
check_bins += e2mkdir
### debos
## native env
ifeq ($(DEBIAN-OS),y)
# libglib2.0-dev
check_debos_libs += glib-2.0
check_libs += gobject-2.0
# libostree-dev
check_libs += ostree-1
check_bins += debootstrap
endif
# systemd-container
check_bins += systemd-nspawn
## docker env
check_bins += docker
## podman env
#check_bins += podman
### qemu test
# swtpm(https://github.com/stefanberger/swtpm)
# swtpm deps: autoconf libtool libtasn1-6-dev libtpms(https://github.com/stefanberger/libtpms) libgnutls28-dev expect gawk socat python3-pip gnutls-bin libseccomp-dev
check_bins += swtpm
check_bins += swtpm_cert
check_bins += swtpm_setup

ifeq ($(findstring check,$(MAKECMDGOALS)),)
CHECK_ERROR := ERROR
CHECK_EXIT := kill -TERM $(MAKEPID);
else
CHECK_ERROR := WARN
endif

check: _check_all
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
	@$(call LOG,INFO,Check Go version)
	$(eval GO_VERSION := $(shell go version | sed -nr 's/.*go([0-9]+\.[0-9]+.?[0-9]?).*/\1/p'))
	$(eval GO_VERSION_MAJOR := $(shell echo $(GO_VERSION) | cut -d . -f 1))
	$(eval GO_VERSION_MINOR := $(shell echo $(GO_VERSION) | cut -d . -f 2))
	if [ "$(GO_VERSION_MAJOR)" -gt "$(GO_VERSION_MAJOR_MIN)" ] || \
	([ "$(GO_VERSION_MAJOR)" -eq "$(GO_VERSION_MAJOR_MIN)" ] && \
	[ "$(GO_VERSION_MINOR)" -ge "$(GO_VERSION_MINOR_MIN)" ]); then \
	  $(call LOG,OK,Go version \"$(GO_VERSION)\" supported); \
	else \
	  $(call LOG,$(CHECK_ERROR),Go version \"$(GO_VERSION)\" is not supported); \
	  $(call LOG,$(CHECK_ERROR),Needs version \"$(GO_VERSION_MIN)\" or later.); \
	  $(CHECK_EXIT) \
	fi;

check_targets += check_swtpm_bin_version
check_swtpm_bin_version: check_swtpm_bin
	@$(call LOG,INFO,Check swtpm version)
	$(eval SWTPM_VERSION := $(shell swtpm --version | cut -d ' ' -f 4 | sed 's/,//'))
	$(eval SWTPM_VERSION_MAJOR := $(shell echo $(SWTPM_VERSION) | cut -d . -f 1))
	$(eval SWTPM_VERSION_MINOR := $(shell echo $(SWTPM_VERSION) | cut -d . -f 2))
	if [ "$(SWTPM_VERSION_MAJOR)" -gt "$(SWTPM_VERSION_MAJOR_MIN)" ] || \
	([ "$(SWTPM_VERSION_MAJOR)" -eq "$(SWTPM_VERSION_MAJOR_MIN)" ] && \
	[ "$(SWTPM_VERSION_MINOR)" -ge "$(SWTPM_VERSION_MINOR_MIN)" ]); then \
	  $(call LOG,OK,swtpm version \"$(SWTPM_VERSION)\" supported); \
	else \
	  $(call LOG,$(CHECK_ERROR),swtpm version \"$(SWTPM_VERSION)\" is not supported); \
	  $(call LOG,$(CHECK_ERROR),Needs version \"$(SWTPM_VERSION_MIN)\" or later.); \
	  $(CHECK_EXIT) \
	fi;


check_targets += $(foreach lib,$(check_libs),check_$(lib)_lib)
check_%_lib:
	@$(call LOG,INFO,Check library:,$*)
	if [ -z "$(check_$*_header)" ]; then \
	  if pkg-config "$*" >/dev/null 2>&1; then \
	    $(call LOG,OK,library found:,$*);\
	  else \
	    $(call LOG,$(CHECK_ERROR),library not found:,$*);\
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

# libc6-i386
check_targets += check_libc_i386
check_libc_i386:
	@$(call LOG,INFO,Check runtime library:,libc(i386)) 
	if [[ ! -f "$(LIBC_I386)" ]];then \
	    $(call LOG,$(CHECK_ERROR),runtime library not found:,$(LIBC_I386));\
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

_check_all: $(check_targets)
