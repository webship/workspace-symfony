---
name: symfony-scenarios
description: Write and run webship-js scenarios for a Symfony app of the Webship Workspace with the Symfony step pack (`@webship-js/symfony-steps`) — the phrases of the pack by area (the session, forms and their errors, messages, the user menu, the navigation and the language chooser, the blog and the back office of the demo application, the error pages, the debug toolbar and the profiler, the mail), the handles of the users registry, and the workspace command that runs them in the app's container. Use when asked to "write a scenario for this Symfony app", "test the back office", "which step is there for the debug toolbar", "add a feature for the comments", or when a `.feature` file of a Symfony project is being written or fixed.
argument-hint: '<app> [what to cover]'
---

# symfony-scenarios

Scenarios for a Symfony app of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of [`@webship-js/symfony-steps`](https://github.com/webship/symfony-steps)
and of [webship-js](https://github.com/webship/webship-js) itself, and run in the app's container
by the workspace's own command. It comes with the Symfony plugin (`@webship.co/workspace-symfony`),
like the builder (`cmd-symfony-project.sh`), the console tool (`cmd-tools-symfony-console.sh`) and
the agents `symfony-site-builder` and `symfony-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The app | `~/workspace/<folder>/<app>`, at `https://<app>.ddev.site` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| Its mail | the mail catcher of the project, `https://<app>.ddev.site:8026` |
| The suite's configuration | `<app>/cucumber.js`: the step definitions it loads, the users registry (`worldParameters.users`), the pages the steps open (`homePath`, `loginPath`, `accountPath`), the mailbox (`mailUrl`) |
| The features | `<app>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The pack's steps | `<app>/node_modules/@webship-js/symfony-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<app>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<app>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <app>
   ```
   It adds webship-js, the step pack, the users registry, the pages and the mailbox and
   `tests/features/site.feature`, and makes sure the default accounts are on the demo application.
   It is safe to run again: it adds what is missing and keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack
   moves, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<app>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/symfony-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase
   is not obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen.
4. **Write the feature** in `<app>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <app> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <app> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <app> --run --tags "@critical"
   bash cmd-tools-testing.sh <app> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The default accounts are on the app already
(`bash cmd-tools-symfony-console.sh <app> --add-users` writes them again, with their name, address,
role and password):

| Handle | Account | What the app does with it |
| --- | --- | --- |
| `administrator` | `administrator` | An administrator of the demo: the back office (its own posts), comments, the profile |
| `user` | `user` | A reader: comments and the profile; the back office answers it with the 403 page |

```gherkin
Given I am a logged in user with the "administrator" user
Then I should be logged in as "administrator"
When I fill in "Current password" with the password of "user"
```

## The phrases, by area

Each line is a phrase the pack or webship-js defines, and each one passed on a demo application
built with `bash cmd-symfony-project.sh <app> --demo --install --add-users --production`. Most
`should` steps also take the negative: `should not see`, `should not be`, `should not offer`.

### The session

```gherkin
Given I am an anonymous user
Given I am a logged in user with the "administrator" user
When I log in as "user" with the login form
When I log in as "administrator" with the login form and "Keep me logged in" unchecked
When I log in with the username "no_such_account" and the password "not-a-password"
When I log out
Then I should be logged in
Then I should not be logged in
Then I should be logged in as "user"
Then I should see the login form
Then a cookie with the name "REMEMBERME" should exist
```

### Forms and messages

```gherkin
When I fill in "Username" with the username of "user"
When I fill in "Password" with the password of "user"
Then the "Fullname" field should hold the name of "user"
Then the "Content" field should have the error "Post content is too short (10 characters minimum)"
Then the "Title" field should have no error
Then the "Title" field should block submission as required
When I press "Save changes" with a forged token
Then the form should have the error "The CSRF token is invalid. Please try to resubmit the form."
Then I should see the success message "Post created successfully!"
Then I should see the error message "Invalid credentials."
When I close the message "Post created successfully!"
When I show the value of the "Password" field
Then the "Password" field should show its value
When I add the tag "lorem" to the "Tags" field
When I remove the tag "lorem" from the "Tags" field
Then the "Tags" field should have the tags "lorem"
When I set the "Published at" date to "2030-01-01 10:00"
```

### The frame of the app

```gherkin
When I open "Account" from the user menu
Then the user menu should name "user"
Then the user menu should offer "Logout"
Then the navigation should have the item "Search"
Then the navigation should show "Homepage" as the current page
When I choose the language "Español"
Then the language chooser should offer "Deutsch"
Then the current language should be "Español"
Then the page should be written from right to left
Then the page language should be "es"
```

### The blog and the back office of the demo

```gherkin
Then the page should list 10 posts
Then I should see the post "Pellentesque vitae velit ex"
When I open the post "Pellentesque vitae velit ex"
Then the post "Pellentesque vitae velit ex" should not be written by "user"
Then the post "Pellentesque vitae velit ex" should have the tag "lorem"
When I filter the posts by the tag "lorem"
Then every post should have the tag "lorem"
When I go to page 2 of the list
When I go to the next page of the list
Then the list should be on page 2
Then the list should have 3 pages
Then the list should have no previous page
When I publish the comment "A comment of a scenario."
Then the post should have 6 comments
Then I should see the comment "A comment of a scenario." by "user"
When I type "vulputate" in the "Search for..." field
When I click "Edit" in the "A post of a scenario" row
When I click the "Delete post" button
When I click "Delete post" in the modal
```

### The framework's own pages and tools

```gherkin
Then I should see the 404 error page
Then the page should not show debug information
When a page of another site sends a form to "/en/login"
Then I should not see the debug toolbar
Then the response should not contain the header "x-debug-token"
Then I should see the debug toolbar
Then the debug toolbar should show the status code 200
Then the debug toolbar should show the route "blog_index"
Then the debug toolbar should show the account "administrator"
Then the debug toolbar should show 0 logged errors
Then the debug toolbar should show at most 10 database queries
When I open the profiler of the page
Then the profiler should show the "GET" request to "/en/blog/" with the status 200
When I open the "Logs" panel of the profiler
```

The debug toolbar and the profiler are there only in the dev environment:
`bash cmd-tools-symfony-console.sh <app> --dev` before those scenarios (tag them `@dev-mode`),
`bash cmd-tools-symfony-console.sh <app> --prod` after.

### The mail

```gherkin
Then an email with the subject "Your post received a comment!" should be sent to "administrator"
Then the email with the subject "Your post received a comment!" to "administrator" should contain "has received a new comment"
Then no email should be sent to "user"
When I open the "this link" link of the email to "administrator"
```

## Traps found on a real app

- **Comments cannot be deleted** in the demo: comment on a post the scenario writes, and delete the
  post at the end (its comments go with it).
- **A new tag stays.** A post saved with a tag the app does not have creates the tag for good: use
  the tags the app lists (`lorem`, `ipsum`, `dolore`, …).
- **The demo's data is drawn at random** when it is loaded: the authors and the tags of its posts.
  Its newest post is published at a random hour of that day and may not be on the blog yet: start
  from the second one, "Pellentesque vitae velit ex".
- **The login page sends every account to the back office.** Signed in from `/en/login`, a reader
  lands on the 403 page; `I am a logged in user with the "user" user` sends it to the blog instead.
- **Two "Delete post" buttons.** The page keeps the confirmation dialog's button hidden in the page:
  `I click the "Delete post" button` presses the one a person sees, then `I click "Delete post" in
  the modal` confirms.
- **A refused form answers 422**, and the browser logs it as a failed resource: the setup leaves
  that line out of the JavaScript errors (`javascript.ignore` in `cucumber.js`). A scenario that
  opens an error page carries `@js-off`.

## Examples

Three features that pass on a demo built with
`bash cmd-symfony-project.sh <app> --demo --install --add-users --production`, after
`bash cmd-tools-testing.sh <app>`. Copy one into `<app>/tests/features/` and run it.

| File | What it shows |
| --- | --- |
| `examples/session.feature` | A login with the form, a wrong password refused, a page that needs an account, a logout |
| `examples/back-office.feature` | A post written with a tag, listed, deleted through the dialog; a post refused by the rules; a reader refused |
| `examples/framework-pages.feature` | The 404 page of a live app, no debug toolbar, a forged login refused, another language |

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Symfony.** Start with `ch10-authentication-authorization.md` (logins, sessions and protected
  pages), `ch06-form-testing-recipes.md` (forms, validation and their messages),
  `ch33-complete-step-definition-reference.md` (every built-in step) and
  `ch21-when-tests-go-bad.md` (flaky, brittle and slow scenarios).
