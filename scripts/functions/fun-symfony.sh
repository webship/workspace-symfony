#!/usr/bin/env bash

# Symfony for the Webship Workspace: build a new web app or the official demo application, run the
# console on it, add its default accounts, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install symfony` in core/scripts/plugins/symfony/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in the project's container
# (DDEV by default: `ddev exec bin/console …`, `ddev composer …`), never on the host. On DDEV the
# container tool gives the app its database and its mailer, so nothing here writes any.
#
# The runtimes: an app is built on DDEV, or with --runtime on Docker Compose, Podman, Kubernetes, Lando
# or Docksal. The commands are the same on each: `ddev <verb>` is DDEV itself on a DDEV project, and on
# another runtime the core's layer (fun-runtime.sh) gives the verb its meaning there. What differs is
# behind symfony_runtime: the address (symfony_url), `.env.local` (symfony_dotenv_set: DDEV has a verb
# of its own for it, the layer has none), the folder `composer create-project` makes the app in (DDEV
# takes the project root, the layer is told "."), and what DDEV gives the app and the other runtimes do
# not (symfony_runtime_config: the database of the project's own stack, db/db/db on the host db, its
# mail catcher, and the .htaccess Apache needs, since DDEV serves the app with nginx).
#
# Four names are the ones the core's tools look for, under the DDEV project type `symfony`:
#   set_symfony_users        the default accounts          (cmd-tools-add-users.sh <project> symfony)
#   add_symfony_users        create them through the app   (the same tool, and --add-users of the builder)
#   cancel_symfony_users     delete them                   (cmd-tools-cancel-users.sh <project> symfony)
#   testing_configure_symfony  the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a Symfony app is tested with, and the release line it is required at.
readonly SYMFONY_STEPS_PACKAGE='@webship-js/symfony-steps';
readonly SYMFONY_STEPS_VERSION='^2.0.0';

# The default accounts, the ones a scenario logs in as: one per role of the demo application.
# Accounts are configuration, created once on the app; a test suite never creates or deletes one.
#   administrator  ROLE_ADMIN: the back office (its posts), comments, the profile
#   user           ROLE_USER: comments and the profile; the back office refuses it
function set_symfony_users() {
  users=(administrator user);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_role='admin' ;
  user_user_role='user' ;
}

# The runtime of the project in this folder, or of a new build (--runtime, else the workspace's
# setting, else DDEV). A core without the runtime layer has DDEV only.
function symfony_runtime() {
  if declare -f runtime_of > /dev/null ; then runtime_of ; else echo 'ddev' ; fi
}

# The address of the app in this folder: https://<name>.ddev.site on DDEV, http://127.0.0.1:<port> on
# Docker Compose, Podman and Lando, the node's address and a port on Kubernetes, http://<name>.docksal.site
# on Docksal. Asked after `ddev config`.
function symfony_url() {
  if declare -f rt_url > /dev/null ; then rt_url ; else echo "https://${PROJECT_NAME}.ddev.site" ; fi
}

# Set keys of a .env file: DDEV's own `ddev dotenv set <file> --a-key=value …`, and on another runtime
# the same keys (A_KEY=value), each where the file has it (commented out or not), else at the end.
function symfony_dotenv_set() {
  if [ "$(symfony_runtime)" == 'ddev' ] ; then
    ddev dotenv set "$@" ;
    return $? ;
  fi
  python3 - "$@" <<'PYEOF'
import re, sys
path, pairs = sys.argv[1], []
for arg in sys.argv[2:]:
    m = re.match(r'^--([a-z0-9][a-z0-9-]*)=(.*)$', arg, re.S)
    if not m:
        sys.exit('symfony_dotenv_set: --a-key=value, not ' + arg)
    value = m.group(2)
    if re.search(r'[\s#"\'$\\&?]', value):
        value = '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    pairs.append((m.group(1).upper().replace('-', '_'), value))
try:
    lines = open(path).read().split('\n')
except FileNotFoundError:
    lines = []
if lines and lines[-1] == '':
    lines.pop()
for key, value in pairs:
    found = [i for i, l in enumerate(lines) if re.match(r'^\s*' + re.escape(key) + r'\s*=', l)] \
        or [i for i, l in enumerate(lines) if re.match(r'^\s*#\s*' + re.escape(key) + r'\s*=', l)]
    if found:
        lines[found[0]] = key + '=' + value
    else:
        lines.append(key + '=' + value)
open(path, 'w').write('\n'.join(lines) + '\n')
PYEOF
}

# What DDEV gives a symfony project, and the other runtimes do not: the database of the project's own
# stack (db, db, db on the host db, as on every runtime) and its mail catcher (Mailpit on the host
# mail, Lando's on mailpit, port 1025), in .env.local; and, since the web server there is Apache, not
# DDEV's nginx, the .htaccess that sends every path to public/index.php (the one of symfony/apache-pack),
# when the app has none. Only on a runtime that is not DDEV, in the project folder.
function symfony_runtime_config() {
  local mail_host='mail' ;
  [ "$(symfony_runtime)" == 'lando' ] && mail_host='mailpit' ;
  symfony_dotenv_set .env.local \
    --database-url="mysql://db:db@db:3306/db?serverVersion=10.11.0-MariaDB&charset=utf8mb4" \
    --mailer-dsn="smtp://${mail_host}:1025" || return 1 ;
  [ -f "${distribution_webroot:-public}/.htaccess" ] && return 0 ;
  cat > "${distribution_webroot:-public}/.htaccess" <<'HTACCESS'
# Written by the Webship Workspace for Apache, the web server of its container runtimes: the file of
# symfony/apache-pack, which sends every path that is not a file to index.php.
DirectoryIndex index.php

<IfModule mod_negotiation.c>
    Options -MultiViews
</IfModule>

<IfModule mod_rewrite.c>
    RewriteEngine On

    RewriteCond %{REQUEST_URI}::$0 ^(/.+)/(.*)::\2$
    RewriteRule .* - [E=BASE:%1]

    RewriteCond %{HTTP:Authorization} .+
    RewriteRule ^ - [E=HTTP_AUTHORIZATION:%0]

    RewriteCond %{ENV:REDIRECT_STATUS} =""
    RewriteRule ^index\.php(?:/(.*)|$) %{ENV:BASE}/$1 [R=301,L]

    RewriteCond %{REQUEST_FILENAME} -f
    RewriteRule ^ - [L]

    RewriteRule ^ %{ENV:BASE}/index.php [L]
</IfModule>

<IfModule !mod_rewrite.c>
    <IfModule mod_alias.c>
        RedirectMatch 307 ^/$ /index.php/
    </IfModule>
</IfModule>
HTACCESS
}

# Is this folder a Symfony project? Its project type says so: on DDEV in .ddev/config.yaml, on another
# runtime in the x-webship block, both read by the core's rt_is_platform.
function symfony_is_project() {
  local project_path="$1";
  if declare -f rt_is_platform > /dev/null ; then
    rt_is_platform "${project_path}" symfony ;
    return $? ;
  fi
  grep -qE '^type:[[:space:]]*"?symfony"?[[:space:]]*$' "${project_path}/.ddev/config.yaml" 2>/dev/null ;
}

# Go to the project a tool was asked about, or say why not.
function symfony_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! symfony_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Symfony project (its project type is not symfony)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# Write accounts through the app itself: its user entity (App\Entity\User, the one of the demo
# application) and Doctrine, with a password hashed the way the app's "auto" hasher reads it. Reads
# lines of "name|email|password|role" (role: admin or user) on standard input; "delete" as the first
# argument removes the accounts of those names instead (an account that wrote posts is kept), and
# "list" lists every account of the app. An account that is there gets its name, address, role and
# password back. Runs in the project folder, in the container. Returns 3 for an app that has no such
# user entity (a new web app has none).
function symfony_write_accounts() {
  local action="${1:-save}" script=".webship-accounts-$$.php" list=".webship-accounts-$$.txt" ;
  cat > "${list}" ;
  cat > "${script}" <<'PHPEOF'
<?php
// Written by the Symfony plugin of the Webship Workspace for one run, then removed.
use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\PasswordHasher\Hasher\NativePasswordHasher;

require __DIR__.'/vendor/autoload.php';
(new Dotenv())->bootEnv(__DIR__.'/.env');
$class = 'App\Entity\User';
foreach (['setUsername', 'setFullName', 'setEmail', 'setRoles', 'setPassword'] as $method) {
    if (!class_exists($class) || !method_exists($class, $method)) {
        fwrite(STDERR, "  This app has no accounts the plugin can write: no App\\Entity\\User with {$method}() (the demo application has one).\n");
        exit(3);
    }
}
$kernel = new App\Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();
$em = $kernel->getContainer()->get('doctrine')->getManager();
$users = $em->getRepository($class);
[, $action, $file] = $argv + [null, 'list', null];
if ('list' === $action) {
    foreach ($users->findBy([], ['id' => 'ASC']) as $user) {
        printf("  %s, %s <%s> %s\n", $user->getUsername(), $user->getFullName(), $user->getEmail(), implode(' ', $user->getRoles()));
    }
    exit(0);
}
$hasher = new NativePasswordHasher();
foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
    [$name, $email, $password, $role] = array_pad(explode('|', $line), 4, '');
    $user = $users->findOneBy(['username' => $name]);
    if ('delete' === $action) {
        if (!$user) {
            printf("  %s is not there\n", $name);
            continue;
        }
        if (class_exists('App\Entity\Post') && $em->getRepository('App\Entity\Post')->count(['author' => $user]) > 0) {
            printf("  %s kept: it is the author of posts (delete them first)\n", $name);
            continue;
        }
        $em->remove($user);
        $em->flush();
        printf("  %s deleted\n", $name);
        continue;
    }
    $user ??= new $class();
    $user->setUsername($name);
    $user->setFullName($name);
    $user->setEmail($email);
    $user->setRoles(['admin' === $role ? 'ROLE_ADMIN' : 'ROLE_USER']);
    $user->setPassword($hasher->hash($password));
    $em->persist($user);
    $em->flush();
    printf("  %s <%s> %s\n", $user->getUsername(), $user->getEmail(), implode(' ', $user->getRoles()));
}
PHPEOF
  ddev exec php "${script}" "${action}" "${list}" ;
  local rc=$? ;
  rm -f "${script}" "${list}" ;
  return ${rc} ;
}

# The demo application's own data, loaded the way its login page tells a person to: its schema,
# then its fixtures (posts, tags, comments and its users jane_admin, tom_admin and john_user). The
# fixtures come with the demo's development tools, so they load in the dev environment.
function symfony_load_demo_data() {
  ddev exec bin/console doctrine:schema:drop --force --full-database --quiet || return 1 ;
  ddev exec bin/console doctrine:schema:create --quiet || return 1 ;
  ddev exec bin/console doctrine:fixtures:load --env=dev --no-interaction || return 1 ;
}

# Is the app the demo application? Its composer.json says so, or (from its release 3, whose composer.json
# names no package) its blog controller and its own fixtures do.
function symfony_is_demo() {
  grep -q '"name": *"symfony/symfony-demo"' composer.json 2>/dev/null && return 0 ;
  [ -f src/Controller/BlogController.php ] && [ -f src/DataFixtures/AppFixtures.php ] ;
}

# Has the app accounts the plugin can write? The user entity of the demo application: a username, a
# full name, an address, roles and a password. A new web app has no user entity yet.
function symfony_has_accounts() {
  grep -q 'function setUsername' src/Entity/User.php 2>/dev/null \
    && grep -q 'function setFullName' src/Entity/User.php 2>/dev/null ;
}

# Run the app as a live app runs, or as a development one: the environment in .env.local, the
# assets compiled for a live app, the cache cleared.
function symfony_set_environment() {
  local env="$1" ;
  if [ "${env}" == 'prod' ] ; then
    symfony_dotenv_set .env.local --app-env=prod --app-debug=0 > /dev/null || return 1 ;
    if ddev exec bin/console list asset-map --raw 2>/dev/null | grep -q '^asset-map:compile' ; then
      ddev exec bin/console asset-map:compile --quiet || return 1 ;
    fi
  else
    symfony_dotenv_set .env.local --app-env=dev --app-debug=1 > /dev/null || return 1 ;
    # The compiled assets of a live app would hide the ones the dev server serves.
    rm -rf public/assets ;
  fi
  ddev exec bin/console cache:clear --quiet ;
}

# Build a Symfony app from nothing: the container, then a new web app (symfony/skeleton with the
# webapp pack, as the documentation makes one) or, with --demo, the official demo application; with
# --install its database and its first account.
function symfony_build() {
  trim_project_name ;
  local base_url runtime ;
  runtime="$(symfony_runtime)" ;
  if [ "${RUNTIME:-_none_}" != '_none_' ] && [ "${RUNTIME}" != "${runtime}" ] ; then
    echo "--runtime ${RUNTIME} needs a Webship Workspace with the container runtimes (webship/workspace#694): update the workspace, or build on DDEV." ;
    exit 1 ;
  fi
  local php_version="${PHP_VERSION:-${site_php_version:-8.4}}" ;
  local version="${SYMFONY_VERSION:-}" ;

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  ddev config --project-type=symfony --docroot="${distribution_webroot}" --project-name=${PROJECT_NAME} \
    --php-version=${php_version} --nodejs-version=$(ddev_nodejs_version) --auto || exit 1 ;
  # The address is the runtime's to say, once the project is configured: never a written ddev.site.
  base_url="$(symfony_url)" ;
  ddev_up start -y || exit 1 ;

  # DDEV makes the app in the project root; the layer of another runtime is told so (".").
  local into='' ;
  [ "${runtime}" != 'ddev' ] && into='.' ;
  if [ "${DEMO}" == 'yes' ] ; then
    ddev composer create-project "symfony/symfony-demo${version:+:${version}}" ${into} --no-interaction \
      || { echo "composer create-project symfony/symfony-demo failed." ; exit 1 ; } ;
  else
    ddev composer create-project "symfony/skeleton${version:+:${version}}" ${into} --no-interaction \
      || { echo "composer create-project symfony/skeleton failed." ; exit 1 ; } ;
    # The container tool runs the app: no Docker Compose files from the recipes (the answer the DDEV
    # quickstart for Symfony gives to their question).
    ddev composer config --json extra.symfony.docker false || exit 1 ;
    ddev composer require webapp --no-interaction || { echo "composer require webapp failed." ; exit 1 ; } ;
  fi
  if [ "${runtime}" == 'ddev' ] ; then
    # DDEV writes the database and the mailer of the container into .env.local on start.
    ddev_up restart || exit 1 ;
  else
    # What DDEV gives the app: the database and the mailer of the container, and its web server's rules.
    symfony_runtime_config || { echo "The .env.local of the app could not be written." ; exit 1 ; } ;
  fi

  if [ "${INSTALL}" == 'yes' ] ; then
    if symfony_is_demo ; then
      symfony_load_demo_data || { echo "The demo's data could not be loaded." ; exit 1 ; } ;
      # The workspace account: an administrator of the demo, the first account of the workspace.
      printf '%s|%s|%s|admin\n' "${account_name}" "${account_mail}" "${account_pass}" | symfony_write_accounts save > /dev/null \
        || { echo "The workspace account could not be written." ; exit 1 ; } ;
    else
      ddev exec bin/console doctrine:database:create --if-not-exists --quiet 2>/dev/null ;
      if ls migrations/*.php > /dev/null 2>&1 ; then
        ddev exec bin/console doctrine:migrations:migrate --no-interaction || { echo "The migrations failed." ; exit 1 ; } ;
      fi
    fi

    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_symfony_users ;
      add_symfony_users ;
      cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
    fi

    if [ "${PRODUCTION}" == 'yes' ] ; then
      symfony_set_environment prod || { echo "The app could not be switched to production." ; exit 1 ; } ;
    fi

    echo "${doc_name} ${PROJECT_NAME} has been installed: $(ddev exec bin/console --version 2>/dev/null | head -n 1)$(symfony_is_demo && echo ', the demo application')." ;
    if symfony_is_demo ; then
      echo "Go to ${base_url}/en/login and log in as ${account_name}" ;
    else
      echo "Go to ${base_url}" ;
    fi
  else
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: there is no data to add accounts to yet." ;
    echo "${doc_name} ${PROJECT_NAME} is ready: load its data with bash cmd-symfony-project.sh ${PROJECT_NAME} --install, or run the console with bash cmd-tools-symfony-console.sh ${PROJECT_NAME} --run \"<command>\"" ;
    echo "Go to ${base_url}" ;
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts through the app. An account that is already there gets its name,
# address, role and password back. The list is loaded by the caller (set_symfony_users): the core's
# add_users, the builder, the console tool.
function add_symfony_users() {
  symfony_enter_project || return 1 ;
  if ! symfony_has_accounts ; then
    echo "  ${PROJECT_NAME} has no accounts the plugin can write: a new web app has no user entity (the demo application has one: --demo)." ;
    cd ${WORKSPACE_ROOT}/${doc_name};
    return 0 ;
  fi
  local user user_name user_mail user_password user_role lines="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role:-user}";
    echo " ================================================================= ";

    lines="${lines}${!user_name}|${!user_mail}|${!user_password}|${!user_role:-user}"$'\n' ;
  done
  printf '%s' "${lines}" | symfony_write_accounts save ;
  local rc=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${rc} ;
}

# Delete the default accounts (an account that wrote posts is kept, and the tool says so).
function cancel_symfony_users() {
  symfony_enter_project || return 1 ;
  if ! symfony_has_accounts ; then
    echo "  ${PROJECT_NAME} has no accounts the plugin wrote: a new web app has no user entity." ;
    cd ${WORKSPACE_ROOT}/${doc_name};
    return 0 ;
  fi
  local user user_name user_mail lines="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
    lines="${lines}${!user_name}|${!user_mail}||"$'\n' ;
  done
  printf '%s' "${lines}" | symfony_write_accounts delete ;
  local rc=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${rc} ;
}

# What cmd-tools-symfony-console.sh does: the first of --run, --update, --dev, --prod, --reload-data,
# --add-users, --cancel-users that was asked for; with none of them, what the app is.
function symfony_console_tool() {
  trim_project_name ;
  symfony_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Unquoted on purpose: --run "debug:router --show-controllers" is a command and its arguments.
    ddev exec bin/console ${RUN} ;
    exit $? ;
  fi

  if [ "${UPDATE}" == 'yes' ] ; then
    ddev composer update --no-interaction ;
    ddev exec bin/console cache:clear ;
  elif [ "${DEV}" == 'yes' ] ; then
    symfony_set_environment dev && echo "${PROJECT_NAME} runs in the dev environment: the debug toolbar, the profiler and the debug page are on." ;
  elif [ "${PROD}" == 'yes' ] ; then
    symfony_set_environment prod && echo "${PROJECT_NAME} runs as a live app runs (APP_ENV=prod, APP_DEBUG=0)." ;
  elif [ "${RELOAD_DATA}" == 'yes' ] ; then
    if ! symfony_is_demo ; then
      echo "${PROJECT_NAME} is not the demo application: it has no data of the demo to load." ;
      exit 1 ;
    fi
    symfony_load_demo_data && echo "The demo's data is loaded again: add the default accounts with --add-users." ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_symfony_users ;
    add_symfony_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_symfony_users ;
    cancel_symfony_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}: $(ddev exec bin/console --version 2>/dev/null | head -n 1)$(symfony_is_demo && echo ', the demo application') at $(symfony_url)" ;
    echo "" ; ddev exec bin/console about 2>/dev/null | sed -n '/Kernel/,/Environment/p' ;
    echo "" ; echo "Accounts:" ;
    if symfony_has_accounts ; then
      printf '' | symfony_write_accounts list ;
    else
      echo "  (none the plugin can list: a new web app has no user entity)" ;
    fi
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Symfony project. The core's testing_configure calls this
# in the project folder once webship-js is scaffolded and before the dependencies are installed;
# for a project that is not Symfony it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's
# own, gives cucumber.js the users registry of the default accounts (a handle a scenario reads,
# mapped to an account; never the workspace account), the pages the steps open, the mailbox of the
# project, the tag that keeps the pack's dev lane out of a normal run and the 422 the browser logs
# for every refused form, and writes a first feature when the project has none of its own. Every
# part is skipped when it is already there, so a second run adds what the first missed and never
# resets a suite.
function testing_configure_symfony() {
  local project_path="$1";
  symfony_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Symfony: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Symfony step pack (${SYMFONY_STEPS_PACKAGE} ${SYMFONY_STEPS_VERSION}).";
  set_symfony_users ;
  local registry="" user user_name user_mail user_password ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_mail}|${!user_password}|${!user_name}"$'\n' ;
  done

  python3 - "${project_path}" "${SYMFONY_STEPS_PACKAGE}" "${SYMFONY_STEPS_VERSION}" 'SYMFONY' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, the users registry, the pages
# the steps open, the mailbox, the tag of the pack's dev lane and the 422 of a refused form.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's dev lane needs the app in the dev environment (@dev-mode: the debug toolbar and the",
            pad + "// profiler; bash cmd-tools-symfony-console.sh <app> --dev), and its assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail and not @dev-mode',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the dev lane of the pack out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*homePath:", src, re.M):
    additions += [
        pad + "// The page the login step sends an account to, the login page, and a page only an account may open.",
        pad + "homePath: process.env.HOME_PATH || '/en/blog/',",
        pad + "loginPath: process.env.LOGIN_PATH || '/en/login',",
        pad + "accountPath: process.env.ACCOUNT_PATH || '/en/profile/edit',",
    ]
if not re.search(r"^[ \t]*mailUrl:", src, re.M):
    additions += [
        pad + "// The mailbox that catches the mail of the app (the mail steps read it).",
        pad + "mailUrl: process.env.MAIL_URL || (process.env.LAUNCH_URL || '').replace(/\\/+$/, '') + ':8026',",
    ]
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// The browser logs a 422 for every form the app refuses (the status of a form with errors): not a fault of the app.",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], ignore: 'the server responded with a status of 422' },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this app (the default",
        pad + "// accounts: cmd-tools-add-users.sh). Override one with %s_<HANDLE>_USERNAME and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, email, password, name in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', password: process.env.%s_PASSWORD || '%s', name: '%s', email: '%s' }," % (handle, env, handle, env, password, name, email))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

# An app whose package.json says "type": "module" makes node read every .js file of it as an ES
# module: the CommonJS cucumber.js the scaffold writes cannot load there, and neither can the step
# definitions under tests/. cucumber.js becomes an ES module that exports the same default profile,
# and tests/ gets a package.json of its own that keeps its .js files CommonJS.
if pkg.get('type') == 'module':
    if re.search(r"^module\.exports\s*=\s*\{", src, re.M) and not re.search(r"^export default ", src, re.M):
        src = re.sub(r"^module\.exports\s*=\s*\{", "// The app's package.json says \"type\": \"module\": this file is an ES module, the profiles stay as they were.\nconst config = {", src, count=1, flags=re.M)
        src = src.rstrip() + '\n\nexport default config.default;\n'
        print('  cucumber.js: an ES module (the package.json of the app says "type": "module")')
    tests_pkg = project + '/tests/package.json'
    try:
        open(tests_pkg)
    except OSError:
        import os
        os.makedirs(project + '/tests', exist_ok=True)
        open(tests_pkg, 'w').write(json.dumps({'type': 'commonjs'}, indent=2) + '\n')
        print('  tests/package.json: the step definitions under tests/ stay CommonJS')

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the app yet: the blog, the login page, each
  # default account where the app sends it.
  local feature="${WORKSPACE_SCRIPTS}/plugins/symfony/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the app" ;
  fi

  # The scenarios log in as the default accounts: make sure an app that has the demo's accounts has them.
  if symfony_is_demo ; then
    ( add_symfony_users > /dev/null ) && echo "  the default accounts are on the app (${users[*]})" ;
  fi
}
