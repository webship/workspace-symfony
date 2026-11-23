#!/usr/bin/env bash

# workspace-name: Symfony (web app or demo)

# Installed by the Symfony plugin (plugins.sh --install symfony); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Symfony app in a container, on DDEV (the default) at https://<name>.ddev.site, or with
# --runtime docker, podman, kubernetes, lando or docksal on that runtime, at the address the build
# prints: a new web app as the documentation
# makes one (symfony/skeleton with the webapp pack), or with --demo the official demo application.
# With --install its data is loaded and, for the demo, the workspace account is an administrator; with
# --add-users it also gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="symfony";
distribution_title="Symfony";
distribution_webroot="public";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} app in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/symfony/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/symfony/args/arg-symfony.sh || exit 1 ;

shift $#;

symfony_build ;
