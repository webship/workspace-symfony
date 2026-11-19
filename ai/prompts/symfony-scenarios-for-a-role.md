Write and run webship-js scenarios for what one role does on the Symfony demo application.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write scenarios for what the <administrator|user> account does on this app, and run them
# ~/workspace/<folder>/<app> · https://<app>.ddev.site · container-based (DDEV by default)
# the phrases are in the symfony-scenarios skill; the symfony-tester agent is the one to hand this work over to
# look at the app first: in the Playwright MCP browser, in a tab of your own, do each thing by hand once before writing its scenario
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

What to cover:
<the pages and tasks of this role that matter here, one per line>

Read the installed steps first:
grep -hE '^(Given|When|Then)\(' node_modules/@webship-js/symfony-steps/tests/step-definitions/*.steps.js

Write one feature in tests/features/<role>.feature, from phrases that exist.
Log in by the handle of the users registry (administrator, user):
no password in the feature, no account created by a scenario, no platform name in a step phrase.
What a scenario changes, it changes back in the same scenario: a post it writes, it deletes.

Then, from the sites folder (cd ..):
bash cmd-tools-testing.sh <app> --dry-run --path tests/features/<role>.feature
bash cmd-tools-testing.sh <app> --run --path tests/features/<role>.feature

A failing scenario is a result: tell me what the app did, do not loosen the scenario.
When you are done: the scenarios, the result of the run, and any step you could not find in the pack
"""
```
