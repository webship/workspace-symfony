#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-d', '--demo',
                    action='store_true',
                    default=False,
                    help='Make the official demo application (symfony/symfony-demo: a blog with comments, a back office, a profile, the language chooser) instead of a new web app.')
parser.add_argument('-s', '--symfony-version',
                    default="",
                    help='The release to make the app from: of the demo with --demo (Example: 2.9.0, the release on the long-term-support line), else of the skeleton (Example: 7.4.*). Empty means the newest.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Load the data: the demo application gets its own data and the workspace account as an administrator; a new web app gets its database.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator, user): the ones the test scenarios log in as.')
parser.add_argument('-p', '--production',
                    action='store_true',
                    default=False,
                    help='Run the app as a live app runs: APP_ENV=prod and APP_DEBUG=0 (error pages instead of the debug page, no debug toolbar, compiled assets).')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the app in a browser when it is ready.')
parser.add_argument('--php-version',
                    default="8.4",
                    choices=['8.5', '8.4', '8.3', '8.2'],
                    help='PHP version for the project container (the demo application needs 8.4 or later). Example: --php-version 8.4 [default %(default)s]')
ARGEOF
