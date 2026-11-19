---
description: Test a Symfony app of the Webship Workspace with webship-js and the Symfony step pack — set the testing stack up when it is missing, match every step, run the suite (or one feature, or one tag) in the app's container, and report what failed and why.
argument-hint: '<app> [tests/features/<name>.feature | @tag]'
---

# /symfony-test

Test the Symfony app named in: `$ARGUMENTS`

`$ARGUMENTS` stands for what was typed after the command. An AI CLI that does not fill it in
reads the same from the request: the name of the app, then, if anything, one feature path or one
tag.

The first word is the app (its folder name in a sites folder of the workspace). What follows, if
anything, narrows the run: a path that starts with `tests/features/` is one feature (or one
folder of features), a word that starts with `@` is a tag expression. With nothing after the app,
the whole suite runs. With no app at all, stop and ask for one: list the candidates with
`grep -lE '^type: *"?symfony"?' ~/workspace/*/*/.ddev/config.yaml`.

The workspace is container-based (DDEV by default) and everything below runs in the app's
container through the workspace's own command. Never run `npx cucumber-js`, `npx playwright`,
`php`, `composer` or `bin/console` on the host for an app.

## 1. Find the app

```bash
ls -d ~/workspace/*/<app>/.ddev/config.yaml
grep -E '^type:' ~/workspace/<folder>/<app>/.ddev/config.yaml
```

`<folder>` is the sites folder the app is in (`dev`, `test`, `sandboxes`, `demos`). If the type is
not `symfony`, stop: this command is for an app built with `cmd-symfony-project.sh`. If `<folder>`
has no `cmd-tools-testing.sh`, stop and say that the folder is not a sites folder of this
workspace.

## 2. Make sure the testing stack is there

```bash
cd ~/workspace/<folder>
grep -c "@webship-js/symfony-steps" <app>/cucumber.js
```

If `cucumber.js` is missing or does not name the step pack, set the stack up (it adds what is
missing and keeps what was changed):

```bash
bash cmd-tools-testing.sh <app>
```

## 3. Match every step, without a browser

```bash
bash cmd-tools-testing.sh <app> --dry-run                                        # the whole suite
bash cmd-tools-testing.sh <app> --dry-run --path tests/features/<name>.feature   # one feature
bash cmd-tools-testing.sh <app> --dry-run --tags "@critical"                     # one tag
```

Use the form that matches what was asked. An `Undefined` or `Ambiguous` step is a finding: name
the feature, the line and the phrase, show the closest phrase the pack defines
(`grep -hE "^(Given|When|Then)\(" <app>/node_modules/@webship-js/symfony-steps/tests/step-definitions/*.steps.js`),
and stop before the real run.

## 4. Run

```bash
bash cmd-tools-testing.sh <app> --run                                            # the whole suite
bash cmd-tools-testing.sh <app> --run --path tests/features/<name>.feature       # one feature
bash cmd-tools-testing.sh <app> --run --tags "@critical"                         # one tag
```

Run it once. Do not add `--retry`, do not tag a scenario `@wip` and do not change a feature to
make the run pass. The `@dev-mode` scenarios need the app in the dev environment: run them only
when that tag was asked for, after `bash cmd-tools-symfony-console.sh <app> --dev`, and put the app
back with `bash cmd-tools-symfony-console.sh <app> --prod`.

## 5. Report

Say, in this order:

1. The app, its address (`https://<app>.ddev.site`) and what was run (suite, feature or tag).
2. The totals the run printed: scenarios and steps, passed and failed, and the time.
3. For each failed scenario: the feature and line, the step that failed, the message, and what
   it means for the app — a defect of the app, a scenario that asserts something the app never
   did, or the environment (the app was stopped, an account is missing:
   `bash cmd-tools-symfony-console.sh <app> --add-users` writes the default ones again; the app runs
   in the dev environment where a live one was expected: `bash cmd-tools-symfony-console.sh <app> --prod`).
4. Where the report is: `~/workspace/<folder>/<app>/tests/reports/`.

A failing suite is a result: report it as it is. Never create an account for a scenario, never
write a password into a feature file, and never write a platform name into a step phrase. For
writing or fixing scenarios, use the `symfony-scenarios` skill or hand over to the
`symfony-tester` agent; for changing the app, to `symfony-site-builder`.

Before you write or change a scenario, or read a failed run, read the book *Automated Functional
Testing Recipes* (its `README.md`, then the matching chapter):
`.claude/automated-functional-testing-recipes/` in the project,
`~/.claude/automated-functional-testing-recipes/`, or
https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
