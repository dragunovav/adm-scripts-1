#!/usr/bin/env bash
set -eu -o pipefail  # Abort on errors, disallow undefined variables
IFS=$'\n\t'          # Apply word splitting only on newlines and tabs

# Clone all Git repos related to Kurento external libraries.
#
# Changes:
# 2018-02-09 Juan Navarro <juan.navarro@gmx.es>
# - Initial version.
# 2018-02-13
# - Print the list of repos that will get cloned.
# - Don't hide stderr from `git clone`.

# Settings
BASE_URL="https://github.com/Kurento"

REPOS=(
  gstreamer
  libsrtp
  openh264
  usrsctp
  jsoncpp
  gst-plugins-base
  gst-plugins-good
  gst-plugins-ugly
  gst-plugins-bad
  gst-libav
  openwebrtc-gst-plugins
  libnice
)

echo "==== Clone Git repositories ===="
echo "This script will clone all Kurento External repos:"
printf '%s\n' "${REPOS[@]}"
read -p "Are you sure? Type 'yes': " -r SURE
[ "$SURE" != "yes" ] && [ "$SURE" != "YES" ] && { echo "Aborting"; exit 1; }

echo "Working..."

for REPO in "${REPOS[@]}"; do
  REPO_URL="${BASE_URL}/${REPO}"
  if [ -d "$REPO" ]; then
    echo "Skip already existing: $REPO"
  else
    echo "Clone repository: $REPO"
    git clone "$REPO_URL" >/dev/null
  fi
done

echo ""
echo "Git repositories cloned at ${PWD}/"

# ------------

echo ""
echo "[$0] Done."
