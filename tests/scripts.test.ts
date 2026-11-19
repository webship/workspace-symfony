import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-symfony.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(type: string, demo = true) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'symfony-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${type}\ndocroot: public\n`);
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  fs.writeFileSync(path.join(dir, 'composer.json'), JSON.stringify({ name: demo ? 'symfony/symfony-demo' : 'symfony/skeleton', type: 'project' }, null, 4));
  if (demo) {
    // The user entity of the demo application, as far as the plugin reads it.
    fs.mkdirSync(path.join(dir, 'src', 'Entity'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'src', 'Entity', 'User.php'), '<?php\nclass User {\n  public function setUsername(string $u): void {}\n  public function setFullName(string $n): void {}\n}\n');
  }
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'symfony'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'symfony', 'site.feature'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder (the list it is given goes to the log too). */
function bash(script: string, env: Record<string, string> = {}) {
  const r = spawnSync('bash', ['-c', `ddev() { echo "ddev $*" >> "\${DDEV_LOG:-/dev/null}" ; if [ "$1" == "exec" ] && [ "$2" == "php" ] && [ -f "$5" ] ; then cat "$5" >> "\${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }\nsource ${FUNCTIONS}\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env } });
  return r;
}

test('the default accounts are one per role of the demo application, with example addresses', () => {
  const r = bash('set_symfony_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; l="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!l}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'user']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['admin', 'user']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.match(name, /^[a-z_]+$/, 'a username the demo application takes');
    assert.ok(password.length >= 6, 'long enough for the demo application');
  }
});

test('the accounts are written through the app, with their role, and removed through it', () => {
  const p = project('symfony');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  let r = bash('set_symfony_users ; add_symfony_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  let written = fs.readFileSync(log, 'utf8');
  assert.match(written, /ddev exec php \.webship-accounts-\d+\.php save \.webship-accounts-\d+\.txt/);
  assert.match(written, /^administrator\|administrator@example\.com\|[^|]+\|admin$/m);
  assert.match(written, /^user\|user@example\.com\|[^|]+\|user$/m);
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => f.startsWith('.webship-accounts')), [], 'the files of the write are gone');
  fs.writeFileSync(log, '');
  r = bash('set_symfony_users ; cancel_symfony_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  written = fs.readFileSync(log, 'utf8');
  assert.match(written, /ddev exec php \.webship-accounts-\d+\.php delete /);
  assert.match(written, /^administrator\|administrator@example\.com\|\|$/m);
});

test('the script that writes the accounts hashes the password the way the app reads it, and writes no database setting', () => {
  const src = fs.readFileSync(FUNCTIONS, 'utf8');
  const php = src.slice(src.indexOf("<<'PHPEOF'"), src.indexOf('PHPEOF\n  ddev exec php'));
  assert.match(php, /NativePasswordHasher/, 'the hash password_verify reads, which the "auto" hasher of the app accepts');
  assert.match(php, /getContainer\(\)->get\('doctrine'\)/, 'through the app\'s own Doctrine');
  assert.match(php, /exit\(3\)/, 'an app without the user entity of the demo is told so');
  assert.match(php, /author of posts/, 'an account that wrote posts is kept');
  assert.doesNotMatch(php, /DATABASE_URL|new PDO|mysqli/, 'the app\'s own connection, never one of its own');
});

test('the testing hook adds the step pack, the users registry, the pages, the mailbox, the tags and a first feature to a Symfony project, once', () => {
  const p = project('symfony');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_symfony ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/symfony-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/symfony-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /administrator: \{ username: process\.env\.SYMFONY_ADMINISTRATOR_USERNAME \|\| 'administrator', password: process\.env\.SYMFONY_ADMINISTRATOR_PASSWORD \|\| '[^']+', name: 'administrator', email: 'administrator@example\.com' \},/);
  assert.match(cucumber, /user: \{ username: process\.env\.SYMFONY_USER_USERNAME \|\| 'user'/);
  assert.match(cucumber, /mailUrl: process\.env\.MAIL_URL \|\|/);
  assert.match(cucumber, /homePath: process\.env\.HOME_PATH \|\| '\/en\/blog\/',/);
  assert.match(cucumber, /accountPath: process\.env\.ACCOUNT_PATH \|\| '\/en\/profile\/edit',/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail and not @dev-mode',/);
  assert.match(cucumber, /ignore: 'the server responded with a status of 422'/);
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, typeof c.worldParameters.mailUrl, c.worldParameters.loginPath]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, mail, login] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['administrator', 'user']);
  assert.match(tags, /not @dev-mode/);
  assert.strictEqual(mail, 'string');
  assert.strictEqual(login, '/en/login');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /^administrator\|administrator@example\.com\|[^|]+\|admin$/m, 'the demo application gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the user tools tell a new web app that it has no accounts, and write none', () => {
  const p = project('symfony', false);
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  for (const fn of ['add_symfony_users', 'cancel_symfony_users']) {
    const r = bash(`set_symfony_users ; ${fn}`, env);
    assert.strictEqual(r.status, 0, r.stderr + r.stdout);
    assert.match(r.stdout, /a new web app has no user entity/);
  }
  assert.ok(!fs.existsSync(log), 'nothing ran in the container');
});

test('a new web app gets the step pack, and no accounts it has no place for', () => {
  const p = project('symfony', false);
  const log = path.join(p.root, 'ddev.log');
  const r = bash(`cd ${p.dir} && testing_configure_symfony ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), /@webship-js\/symfony-steps/);
  assert.ok(!fs.existsSync(log) || !/webship-accounts/.test(fs.readFileSync(log, 'utf8')), 'no account is written into an app that is not the demo');
});

test('in an app whose package.json is a module, cucumber.js becomes an ES module and tests/ stays CommonJS, once', () => {
  const p = project('symfony');
  fs.writeFileSync(path.join(p.dir, 'package.json'), JSON.stringify({ name: 'site1', private: true, type: 'module', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const run = () => bash(`cd ${p.dir} && testing_configure_symfony ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const src = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  assert.match(src, /^const config = \{/m);
  assert.doesNotMatch(src, /module\.exports/);
  assert.match(src, /\nexport default config\.default;\n$/);
  assert.deepStrictEqual(JSON.parse(fs.readFileSync(path.join(p.dir, 'tests', 'package.json'), 'utf8')), { type: 'commonjs' });
  // Node reads it the way cucumber-js does in such a package: as an ES module, its default export the default profile.
  const url = 'file://' + path.join(p.dir, 'cucumber.js');
  const loaded = spawnSync(process.execPath, ['--input-type=module', '-e', `const c = (await import(${JSON.stringify(url)})).default; console.log(JSON.stringify([c.require.length, Object.keys(c.worldParameters.users), c.tags]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires, 3);
  assert.deepStrictEqual(handles, ['administrator', 'user']);
  assert.match(tags, /not @dev-mode/);
  // Again: nothing is converted twice.
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), src);
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal11');
  const r = bash(`cd ${p.dir} && testing_configure_symfony ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the console tool refuses a project that is not Symfony', () => {
  const p = project('drupal11');
  const r = bash('PROJECT_NAME=site1 ; RUN="about" ; trim_project_name() { :; } ; symfony_console_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Symfony project/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /symfony|twig|doctrine|live component|stimulus/i, s);
  assert.doesNotMatch(feature, /password "/);
  assert.doesNotMatch(feature, /user create|I register/i, 'a suite never creates an account');
});
