#!/usr/bin/env bash

set -eu

GITHUB_USER="nellaja"
BRANCH="main"
ARTIFACT="ballista-${BRANCH}"

set -o xtrace

curl -sL -o "${ARTIFACT}.zip" "https://github.com/${GITHUB_USER}/ballista/archive/refs/heads/${BRANCH}.zip"
bsdtar -x -f "${ARTIFACT}.zip"
cp -R "${ARTIFACT}"/ballista "${ARTIFACT}"/*.conf "${ARTIFACT}"/Config_Files/ "${ARTIFACT}"/Packages_Units/ ./

chmod +x ./ballista
