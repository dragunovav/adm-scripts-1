#!/usr/bin/env bash

#/ Kurento build script.
#/
#/ This shell script is used to build all Kurento Media Server
#/ modules, and generate Debian/Ubuntu package files from them.
#/
#/ Arguments:
#/
#/ --install-missing <Version>
#/
#/     Use `apt-get` to download and install any missing packages from the
#/     Kurento packages repository for Ubuntu.
#/
#/     <Version> indicates which Kurento version must be used to download
#/     packages from. E.g.: "6.8.0". If "dev" or "nightly" is given, the
#/     Kurento Pre-Release package snapshots will be used instead. Typically,
#/     you will provide an actual version number when also using the '--release'
#/     flag, and just use "nightly" otherwise.
#/
#/     If this argument is not provided, all required dependencies are expected
#/     to be already installed in the system.
#/
#/     This option is useful for end users, or external developers which may
#/     want to build a specific component of Kurento without having to build
#/     all the corresponding dependencies.
#/
#/     Optional. Default: Disabled.
#/
#/ --allow-dirty
#/
#/     Build packages intended for Release.
#/     If this option is not given, packages are built as nightly snapshots.
#/
#/     If none of the '--install-missing' options are given, this build script
#/     expects that all required packages are manually installed beforehand.
#/
#/     Optional. Default: Disabled.
#/
#/ --release
#/
#/     Build packages intended for Release.
#/     If this option is not given, packages are built as nightly snapshots.
#/
#/     If none of the '--install-missing' options are given, this build script
#/     expects that all required packages are manually installed beforehand.
#/
#/     Optional. Default: Disabled.
#/
#/ --timestamp <Timestamp>
#/
#/    Apply the provided timestamp instead of using the date and time this
#/    script is being run.
#/
#/    <Timestamp> must be a decimal number. Ideally, it represents some date
#     and time when the build was done. It can also be any arbitrary number.
#/
#/    Optional. Default: Current date and time, as given by the command
#/    `date --utc +%Y%m%d%H%M%S`.
#/
#/ Dependency tree:
#/
#/ * git-buildpackage (???)
#    2 options:
#    - Ubuntu package: git-buildpackage 0.7.2 in Xenial
#    - Python PIP: gbp 0.9.10
#      - Python 3 (pip, setuptools, wheel)
#      - sudo apt-get install python3-pip python3-setuptools
#      - sudo pip3 install --upgrade gbp
#/   - debuild (package 'devscripts')
#/     - dpkg-buildpackage (package 'dpkg-dev')
#/     - lintian
#/   - git
#/     - openssh-client (for SSH access)
#/ * lsb-release
#/ * mk-build-deps (package 'devscripts')
#/   - equivs
#/ * nproc (package 'coreutils')



# ------------ Shell setup ------------

BASEPATH="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"  # Absolute canonical path
CONF_FILE="$BASEPATH/kurento.conf.sh"
[[ -f "$CONF_FILE" ]] || {
    echo "[$0] ERROR: Shell config file not found: $CONF_FILE"
    exit 1
}
# shellcheck source=kurento.conf.sh
source "$CONF_FILE"



# ------------ Script start ------------

# Check root permissions
[[ "$(id -u)" -eq 0 ]] || { log "Please run as root"; exit 1; }



# ---- Parse arguments ----

PARAM_INSTALL_MISSING="false"
PARAM_INSTALL_VERSION="0.0.0"
PARAM_ALLOW_DIRTY="false"
PARAM_RELEASE="false"
PARAM_TIMESTAMP="$(date --utc +%Y%m%d%H%M%S)"

while [[ $# -gt 0 ]]; do
    case "${1-}" in
        --install-missing)
            if [[ -n "${2-}" ]]; then
                PARAM_INSTALL_MISSING="true"
                PARAM_INSTALL_VERSION="$2"
                shift
            else
                log "ERROR: Missing <Version>"
                exit 1
            fi
            ;;
        --allow-dirty)
            PARAM_ALLOW_DIRTY="true"
            ;;
        --release)
            PARAM_RELEASE="true"
            ;;
        --timestamp)
            if [[ -n "${2-}" ]]; then
                PARAM_TIMESTAMP="$2"
                shift
            else
                log "ERROR: Missing <Timestamp>"
                exit 1
            fi
            ;;
        *)
            log "ERROR: Unknown argument '${1-}'"
            exit 1
            ;;
    esac
    shift
done

log "PARAM_INSTALL_MISSING=${PARAM_INSTALL_MISSING}"
log "PARAM_INSTALL_VERSION=${PARAM_INSTALL_VERSION}"
log "PARAM_ALLOW_DIRTY=${PARAM_ALLOW_DIRTY}"
log "PARAM_RELEASE=${PARAM_RELEASE}"
log "PARAM_TIMESTAMP=${PARAM_TIMESTAMP}"



# ---- Apt configuration ----

# If requested, add the repository
if [[ "$PARAM_INSTALL_MISSING" = "true" ]]; then
    log "Requested installation of missing packages"

    log "Add the Kurento Apt repository key"
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5AFA7A83

    # Set correct repo name for nightly versions
    if [[ "$PARAM_INSTALL_VERSION" = "nightly" ]]; then
        PARAM_INSTALL_VERSION="dev"
    fi

    log "Add the Kurento Apt repository line"
    APT_FILE="$(mktemp /etc/apt/sources.list.d/kurento-XXXXX.list)"
    DISTRO="$(lsb_release --codename --short)"
    echo "deb [arch=amd64] http://ubuntu.openvidu.io/$PARAM_INSTALL_VERSION $DISTRO kms6" \
        >"$APT_FILE"

    # This requires an Apt cache update
    apt-get update
fi



# ---- Dependencies ----

log "Install build dependencies"
mk-build-deps --install --remove \
    --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' \
    ./debian/control



# ---- Changelog ----

# To build Release packages, the 'debian/changelog' file must be updated and
# committed by a developer, as part of the release process. Then the build
# script uses it to assign a version number to the resulting packages.
# For example, a developer would run:
#     gbp dch --git-author --release debian/
#     git add debian/changelog
#     git commit -m "Update debian/changelog with new release version"
#
# For nightly (pre-release) builds, the 'debian/changelog' file is
# auto-generated by the build script with a snapshot version number. This
# snapshot information is never committed.

# --ignore-branch allows building from a tag or a commit.
#   If it wasn't set, GBP would enforce that the current branch is
#   the "debian-branch" specified in 'gbp.conf' (or 'master' by default).
# --git-author uses the Git user details for the entry in 'debian/changelog'.
if [[ "$PARAM_RELEASE" = "true" ]]; then
    log "Update debian/changelog for a release version build"
    gbp dch \
        --ignore-branch \
        --git-author \
        --spawn-editor=never \
        --release \
        ./debian/
else
    log "Update debian/changelog for a nightly snapshot build"
    gbp dch \
        --ignore-branch \
        --git-author \
        --spawn-editor=never \
        --snapshot --snapshot-number="$PARAM_TIMESTAMP" \
        ./debian/
fi



# ---- Build ----

# --git-ignore-branch allows building from a tag or a commit.
#   If it wasn't set, GBP would enforce that the current branch is
#   the "debian-branch" specified in 'gbp.conf' (or 'master' by default).
# --git-upstream-tree=SLOPPY generates the source tarball from the current
#   state of the working directory.
#   If it wasn't set, GBP would search for upstream source files in
#   the "upstream-branch" specified in 'gbp.conf' (or 'upstream' by default).
# --git-ignore-new ignores the uncommitted 'debian/changelog'.
#
# Other arguments are passed to `debuild` and `dpkg-buildpackage`.

# Arguments passed to 'dpkg-buildpackage'
ARGS="-uc -us -j$(nproc)"
if [[ "$PARAM_ALLOW_DIRTY" = "true" ]]; then
    ARGS="$ARGS -b"
fi

if [[ "$PARAM_RELEASE" = "true" ]]; then
    log "Run git-buildpackage to generate a release version build"
    gbp buildpackage \
        --git-ignore-branch \
        --git-ignore-new \
        --git-upstream-tree=SLOPPY \
        $ARGS
else
    log "Run git-buildpackage to generate a nightly snapshot build"
    gbp buildpackage \
        --git-ignore-branch \
        --git-ignore-new \
        --git-upstream-tree=SLOPPY \
        $ARGS
fi

log "Done!"
