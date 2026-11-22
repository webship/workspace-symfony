import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/symfony\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-symfony.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-symfony-project.sh'), /^# workspace-name: Symfony/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-symfony-console.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the functions carry the names the core\'s tools look for, and never write database settings', () => {
  const src = read('scripts/functions/fun-symfony.sh');
  for (const fn of ['set_symfony_users', 'add_symfony_users', 'cancel_symfony_users', 'testing_configure_symfony', 'symfony_build', 'symfony_console_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.doesNotMatch(src, /^function build_symfony\(\)/m, 'the core\'s own example function is not redefined');
  assert.doesNotMatch(src, /--db-(host|database|username|password)|DB_(HOST|DATABASE|USERNAME|PASSWORD)=/, 'the container tool owns the database settings');
  // The database only where DDEV gives it and another runtime does not: symfony_runtime_config, the stack's own values.
  const own = src.slice(src.indexOf('function symfony_runtime_config() {'), src.indexOf('\n}\n', src.indexOf('function symfony_runtime_config() {')));
  assert.match(own, /--database-url="mysql:\/\/db:db@db:3306\/db\?/);
  assert.doesNotMatch(src.replace(own, ''), /--database-url|DATABASE_URL=/, 'the container tool owns the database settings');
  assert.match(src.slice(src.indexOf('function symfony_build() {')), /if \[ "\$\{runtime\}" == 'ddev' \] ; then[\s\S]*ddev_up restart[\s\S]*else[\s\S]*symfony_runtime_config/, 'only on a runtime that is not DDEV');
  assert.doesNotMatch(src.replace(/^\s*#.*$/gm, '').replace(/echo "https:\/\/\$\{PROJECT_NAME\}\.ddev\.site"/, ''), /ddev\.site/, 'ddev.site only as the answer of a core with no layer');
  assert.doesNotMatch(src.replace(/^\s*#.*$/gm, ''), /(?<![.\w])(docker|podman|kubectl) |command ddev/, 'only `ddev <verb>`: the layer chooses');
  assert.match(src, /--project-type=symfony/);
  assert.match(src, /composer create-project "symfony\/symfony-demo/, 'the demo is the official one, made the way its own guide says');
  assert.match(src, /composer create-project "symfony\/skeleton[\s\S]*composer require webapp/, 'a new web app is made as the documentation makes one');
  assert.match(src, /extra\.symfony\.docker false[\s\S]*composer require webapp/, 'no Docker Compose files from the recipes: the container tool runs the app');
  assert.match(src, /doctrine:fixtures:load --env=dev/, "the demo's data is its own fixtures");
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the build runs the Node.js of the workspace rule');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-symfony-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/symfony-tester.md');
  assert.match(tester, /Never create an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'symfony', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-symfony.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
});
