#!/bin/bash -x
echo "##################### EXECUTE: kurento_merge_js_project_container #####################"

# KURENTO_PROJECT string
#   Optional
#   Name of the project to be merged
#
# BASE_NAME
#   Optional
#   Name of the artifact.
#   Default: PROJECT_NAME
#
# CREATE_TAG
#   Flag to indicate if a tag is needed in case of a release version
#
# KURENTO_GIT_REPOSITORY_SERVER string
#   URL of Kurento code repository
#
# MAVEN_SETTINGS
#   Location of settings.xml maven configuration file
#
# MAVEN_KURENTO_SNAPSHOTS url
#   URL of Kurento repository for maven snapshots
#
# MAVEN_KURENTO_RELEASES url
#   URL of Kurento repository for maven releases
#
# MAVEN_SONATYPE_NEXUS_STAGING url
#   URL of Central staging repositories
#
# BOWER_REPOSITORY url
#   URL to bower repository
#
# FILES
#   List of files to publish to $BUILDS_HOST
#
# BUILDS_HOST
#   Server to publish artifacts specified in $FILES
#
# BUILD_COMMAND
#   Command to run in the container after initialization
#
# CERT
#   Jenkins certificate to upload artifacts to http services
#
# KEY
#   Gerrit ssh key
#
# GERRIT_HOST
#   Gerrit host
#
# GERRIT_PORT
#   Gerrit port
#
# GERRIT_PROJECT
#   Gerrit project
#
# GERRIT_NEWREV
#   Gerrit revision


# Verify mandatory parameters
[ -z "$KURENTO_PROJECT" ] && KURENTO_PROJECT=$GERRIT_PROJECT
[ -z "$KURENTO_GIT_REPOSITORY_SERVER" ] && exit 1

[ -z "$BASE_NAME" ] && BASE_NAME=$KURENTO_PROJECT

[ -z "$BUILD_COMMAND" ] && BUILD_COMMAND="kurento_merge_js_project.sh"

# Parameters relative to container filesystem
CONTAINER_WORKSPACE=/opt/kurento
CONTAINER_KEY=/opt/id_rsa
CONTAINER_CERT=/opt/jenkins.crt
CONTAINER_MAVEN_SETTINGS=/opt/kurento-settings.xml
CONTAINER_ADM_SCRIPTS=/opt/adm-scripts
CONTAINER_GIT_CONFIG=/root/.gitconfig
CONTAINER_SSH_CONFIG=/root/.ssh/config

cat >./.root-config <<EOL
StrictHostKeyChecking no
User jenkins
IdentityFile $CONTAINER_KEY
EOL

docker run \
  --name $BUILD_TAG-MERGE_PROJECT \
  --rm \
  -v $KURENTO_SCRIPTS_HOME:$CONTAINER_ADM_SCRIPTS \
  -v $WORKSPACE:$CONTAINER_WORKSPACE \
  -v $MAVEN_SETTINGS:$CONTAINER_MAVEN_SETTINGS \
  -v $KEY:$CONTAINER_KEY \
  -v $CERT:$CONTAINER_CERT \
  -v $PWD/.root-config:$CONTAINER_SSH_CONFIG \
  -v $GIT_CONFIG:$CONTAINER_GIT_CONFIG \
  -e "KURENTO_PROJECT=$KURENTO_PROJECT" \
  -e "BASE_NAME=$BASE_NAME" \
  -e "MAVEN_SETTINGS=$CONTAINER_MAVEN_SETTINGS" \
  -e "KURENTO_GIT_REPOSITORY_SERVER=$KURENTO_GIT_REPOSITORY_SERVER" \
  -e "MAVEN_KURENTO_SNAPSHOTS=$MAVEN_KURENTO_SNAPSHOTS" \
  -e "MAVEN_KURENTO_RELEASES=$MAVEN_KURENTO_RELEASES" \
  -e "MAVEN_SONATYPE_NEXUS_STAGING=$MAVEN_SONATYPE_NEXUS_STAGING" \
  -e "MAVEN_SHELL_SCRIPT=$MAVEN_SHELL_SCRIPT" \
  -e "ASSEMBLY_FILE=$ASSEMBLY_FILE" \
  -e "BOWER_REPOSITORY=$BOWER_REPOSITORY" \
  -e "FILES=$FILES" \
  -e "BUILDS_HOST=$BUILDS_HOST" \
  -e "KEY=$CONTAINER_KEY" \
  -e "CERT=/opt/jenkins.crt" \
  -e "SSH_CONFIG=$CONTAINER_SSH_CONFIG" \
  -e "CREATE_TAG=$CREATE_TAG" \
  -e "GERRIT_HOST=$GERRIT_HOST" \
  -e "GERRIT_PORT=$GERRIT_PORT" \
  -e "GERRIT_PROJECT=$GERRIT_PROJECT" \
  -e "GERRIT_NEWREV=$GERRIT_NEWREV" \
  -u "root" \
  -w "$CONTAINER_WORKSPACE" \
    kurento/dev-integration:jdk-8-node-0.12 \
      /opt/adm-scripts/kurento_ci_container_entrypoint.sh $BUILD_COMMAND || status=$?

exit $status