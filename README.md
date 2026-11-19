# @webship.co/workspace-symfony

Symfony for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that
makes a real Symfony app in a container, a new web app as the documentation makes one or the
official demo application, a console tool for the apps it built, the default accounts, the
[Symfony step pack](https://github.com/webship/symfony-steps) wired into the workspace's testing
setup, and its AI items — two agents, a skill, a command and two prompts — each listed in the
workspace folder of its kind.

The workspace is container-based (DDEV by default): a Symfony project is a row like any other, so
the row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it
unchanged.

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-symfony --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate symfony --with-needs                         # plugins.symfony in settings.yml
bash core/scripts/plugins.sh --install symfony                                       # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure symfony                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-symfony-project.sh`, `cmd-tools-symfony-console.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `symfony-site-builder`, `symfony-tester` | `ai-agents/` |
| The skill `symfony-scenarios` | `ai-skills/` |
| The command `/symfony-test` | `ai-commands/` |
| The prompts `symfony-build-and-test`, `symfony-scenarios-for-a-role` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate symfony --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install symfony
```

Everything the builder runs for an app runs in the app's own container, through the container tool the workspace already needs: Composer is in the web container. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-symfony-project.sh` | The builder, in the Build list as **Symfony (web app or demo)**, installed into every sites folder |
| `commands/cmd-tools-symfony-console.sh` | The console for one app: what the app is, a command, updates, the dev or the live environment, the demo's data, the default accounts |
| `scripts/functions/fun-symfony.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_symfony_users`, `add_symfony_users`, `cancel_symfony_users`, `testing_configure_symfony`) |
| `scripts/args/arg-symfony.sh`, `arg-symfony-console.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `testing/site.feature` | The first feature a Symfony project gets when testing is set up |
| `ai/agents/symfony-site-builder.md` | The agent that builds and maintains Symfony apps with these commands |
| `ai/agents/symfony-tester.md` | The agent that writes and runs scenarios with the Symfony step pack |
| `ai/skills/symfony-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real app, three example features |
| `ai/commands/symfony-test.md` | The slash command `/symfony-test <app>`: set up, match every step, run, report |
| `ai/prompts/symfony-build-and-test.md`, `symfony-scenarios-for-a-role.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Symfony here |
| `features/symfony.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build an app

```bash
cd ~/workspace/dev
bash cmd-symfony-project.sh myapp --demo --install --add-users
```

| Flag | What it does |
| --- | --- |
| `--demo` | The official demo application (`symfony/symfony-demo`): a blog with comments, a back office, a profile, the language chooser. Without it, a new web app as the documentation makes one (`symfony/skeleton` with the `webapp` pack) |
| `--symfony-version <x>` | The release to make the app from: of the demo with `--demo` (`2.9.0` is its release on Symfony 7.4, the long-term-support line), else of the skeleton (`7.4.*`). Empty means the newest |
| `--install` | Load the data: the demo gets its own data (its posts, comments and users, from its fixtures) and the workspace account as an administrator; a new web app gets its database |
| `--add-users` | With `--install`: add the default accounts |
| `--production` | Run the app as a live app runs: `APP_ENV=prod`, `APP_DEBUG=0` (error pages instead of the debug page, no debug toolbar, the assets compiled) |
| `--php-version <x>` | The PHP of the project container (8.4 by default: the demo needs 8.4 or later) |
| `--launch` | Open the app when it is ready |

The app answers at `https://myapp.ddev.site`, the demo's login at `/en/login`, its mail catcher at
`https://myapp.ddev.site:8026`. The build runs `ddev config --project-type=symfony` with the
Node.js of the workspace (24), makes the app with Composer in the web container
(`composer create-project symfony/symfony-demo`, or `symfony/skeleton` and `composer require
webapp`, without the Docker Compose files of the recipes: the container tool runs the app), and
leaves the database and the mailer to the container tool (it writes them into `.env.local`): it
writes none. A project of the same name is deleted first.

### Work on an app

```bash
bash cmd-tools-symfony-console.sh myapp                                  # version, environment, accounts
bash cmd-tools-symfony-console.sh myapp --run "debug:router"
bash cmd-tools-symfony-console.sh myapp --update                         # Composer packages, then the cache
bash cmd-tools-symfony-console.sh myapp --dev                            # the debug toolbar, the profiler, the debug page
bash cmd-tools-symfony-console.sh myapp --prod                           # a live app again
bash cmd-tools-symfony-console.sh myapp --reload-data                    # the demo's own data again
bash cmd-tools-symfony-console.sh myapp --add-users                      # the default accounts
bash cmd-tools-symfony-console.sh myapp --cancel-users                   # delete them
```

### The default accounts

| Account | Address | Role | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | an administrator of the demo (`ROLE_ADMIN`): the back office, its own posts | `administrator` |
| `user` | `user@example.com` | a reader (`ROLE_USER`): comments and the profile | `user` |

One account per role of the demo application, each named as its handle, with the password of the
workspace's other default lists. They are for local apps and for tests; the app's first account is
the workspace account and is never written into a test. The row's Users menu (**Add the test
users**) and `bash cmd-tools-add-users.sh myapp symfony` add the same list; adding them again gives
them back their name, address, role and password. They are written through the app itself (its
user entity and Doctrine, the password hashed the way the app reads it), so an app without the
demo's user entity (a new web app) has no accounts to add, and the tools say so. An account that
wrote posts is kept by `--cancel-users`. The demo's own users (`jane_admin`, `tom_admin`,
`john_user`) come with its data.

### Test an app

```bash
bash cmd-tools-testing.sh myapp                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh myapp --run           # run the suite in the container
bash cmd-tools-testing.sh myapp --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Symfony project it also adds
`@webship-js/symfony-steps` to `package.json`, lists its step definitions in `cucumber.js` after
webship-js's own, writes the users registry (the handles above, overridable with
`SYMFONY_<HANDLE>_USERNAME` and `SYMFONY_<HANDLE>_PASSWORD`), the pages the steps open (`homePath`,
`loginPath`, `accountPath`: the demo's), the mailbox of the project (`mailUrl`), the tag that keeps
the pack's dev lane (`@dev-mode`) out of a normal run and the 422 the browser logs for every form
the app refuses, places `tests/features/site.feature` when the project has none, and makes sure the
default accounts are on the demo application. Run it again and it adds what is missing and keeps
what you changed.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `symfony-site-builder` | Build, update, maintain or remove a Symfony app with the commands above, in containers only |
| Agent | `symfony-tester` | Set the testing stack up, look at the app in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `symfony-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on a real app, and three features that pass on a fresh demo |
| Command | `/symfony-test <app> [feature or @tag]` | Run the suite of an app from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `symfony-build-and-test` | Start a session that builds the demo application, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `symfony-scenarios-for-a-role` | Start a session that writes and runs the scenarios of one role |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh symfony-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh symfony-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh symfony-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and
the file layout are Claude Code's, the body of each item is plain Markdown that names no tool or
feature of one CLI, a command says in words what its arguments are, and the text between the
triple quotes of a prompt can be given to another AI CLI as it is.

Every step phrase the items show is checked against the definitions of the step pack and of
webship-js (`tests/fixtures/step-definitions.txt`), and every command and flag against the
plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's
`features/symfony.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).

When the step pack's release line changes, refresh the fixture from a project whose testing stack is
set up: `node <this plugin>/tests/fixtures/refresh-step-definitions.js > <this plugin>/tests/fixtures/step-definitions.txt`.
