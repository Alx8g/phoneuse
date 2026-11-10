#!/bin/sh
# Builds the site and copies it to lxe.co:www/phoneuse.tech (nginx serves it;
# config in deploy/phoneuse.tech.conf).
set -e
cd "$(dirname "$0")"
node build.mjs
rsync -az --delete -e "ssh -o BatchMode=yes" dist/ lxe.co:www/phoneuse.tech/
echo "deployed to https://phoneuse.tech/"
