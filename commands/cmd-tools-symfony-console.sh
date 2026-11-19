#!/usr/bin/env bash

# Installed by the Symfony plugin (plugins.sh --install symfony); __WORKSPACE__ is the workspace it was installed into.
#
# The console of one Symfony app of this workspace, in its container: say what the app is, run a
# console command, update its packages, switch it between the dev environment and a live one, load
# the demo's data again, add or remove the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="symfony";

ARGPARSE_DESCRIPTION="Run the console on a Symfony app of __WORKSPACE__: status, a command, updates, the environment, the demo's data, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/symfony/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/symfony/args/arg-symfony-console.sh || exit 1 ;

shift $#;

symfony_console_tool ;
