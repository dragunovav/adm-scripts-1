#!/usr/bin/env bash

#/ Generate and commit source files for Read The Docs.
#/
#/ Arguments:
#/
#/ --release
#/
#/     Build documentation sources intended for Release.
#/     If this option is not given, sources are built as nightly snapshots.
#/
#/     Optional. Default: Disabled.



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

# ---- Parse arguments ----

PARAM_RELEASE="false"

while [[ $# -gt 0 ]]; do
case "${1-}" in
    --release)
        PARAM_RELEASE="true"
        shift
        ;;
    *)
        log "WARNING: Unknown argument '${1-}'"
        shift
        ;;
esac
done

log "PARAM_RELEASE=${PARAM_RELEASE}"



# ---- Generate sources ----

kurento_clone_repo.sh "$KURENTO_PROJECT"

{
    pushd "$KURENTO_PROJECT"

    [[ -x configure.sh ]] && ./configure.sh

    if [[ -z "${MAVEN_SETTINGS:+x}" ]]; then
        cp Makefile Makefile.ci
    else
        sed -e "s@mvn@mvn --settings ${MAVEN_SETTINGS}@g" Makefile > Makefile.ci
    fi

    make --file=Makefile.ci ci-readthedocs
    rm Makefile.ci

    if [[ "$PARAM_RELEASE" = "true" ]]; then
        log "Command: kurento_check_version (tagging enabled)"
        kurento_check_version.sh "true"
    else
        log "Command: kurento_check_version (tagging disabled)"
        kurento_check_version.sh "false"
    fi

    popd  # $KURENTO_PROJECT
}



# ---- Commit generated sources ----

RTD_PROJECT="${KURENTO_PROJECT}-readthedocs"

kurento_clone_repo.sh "$RTD_PROJECT"

rm -rf "${RTD_PROJECT:?}"/*
cp -a "${KURENTO_PROJECT:?}"/* "${RTD_PROJECT:?}"/

log "Commit and push changes to repo: $RTD_PROJECT"
GIT_COMMIT="$(git rev-parse --short HEAD)"

{
    pushd "$RTD_PROJECT"

    git status
    git diff-index --quiet HEAD || {
      git add --all .
      git commit -m "Code autogenerated from Kurento/${KURENTO_PROJECT}@${GIT_COMMIT}"
      git push origin master
    }

    if [[ "$PARAM_RELEASE" = "true" ]]; then
        log "Command: kurento_check_version (tagging enabled)"
        kurento_check_version.sh "true"
    else
        log "Command: kurento_check_version (tagging disabled)"
        kurento_check_version.sh "false"
    fi

    popd  # $RTD_PROJECT
}
