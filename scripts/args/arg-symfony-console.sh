#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Symfony app in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A console command to run in the app, without the leading bin/console. Example: --run "debug:router"')
parser.add_argument('-u', '--update',
                    action='store_true',
                    default=False,
                    help='Update the Composer packages within their constraints and clear the cache.')
parser.add_argument('--dev',
                    action='store_true',
                    default=False,
                    help='Run the app in the dev environment: the debug toolbar, the profiler and the debug page of an error.')
parser.add_argument('--prod',
                    action='store_true',
                    default=False,
                    help='Run the app as a live app runs: APP_ENV=prod and APP_DEBUG=0, the assets compiled.')
parser.add_argument('--reload-data',
                    action='store_true',
                    default=False,
                    help='The demo application only: load its own data again (its posts, comments and users; the accounts added since are gone).')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its name, address, role and password back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts (one that wrote posts is kept).')
ARGEOF
