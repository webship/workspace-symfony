/**
 * Symfony for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * console tool in the sites folders, their functions and argparse under core/scripts/plugins/symfony/,
 * and its AI items (ai/ in this package) in the folder of their kind: the agents in AI Agents, the skill
 * in AI Skills, the command in AI Commands, the prompts in AI Prompts. The dashboard needs nothing drawn
 * for it: the builder is in the Build list because it is a cmd-*-project.sh, the row menus are the
 * core's, the AI items are listed like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name, which is also the DDEV project type its functions are named after. */
export const PLATFORM = 'symfony';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-symfony-project.sh', 'cmd-tools-symfony-console.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['symfony-site-builder', 'symfony-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['symfony-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['symfony-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['symfony-build-and-test', 'symfony-scenarios-for-a-role'];

/** What the assistant is told about Symfony in this workspace. */
export function assistantContext(): string {
  return [
    'Symfony (a plugin, @webship.co/workspace-symfony): a Symfony app is built with',
    '`bash cmd-symfony-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos):',
    'a new web app as the documentation makes one, or with `--demo` the official demo application (a blog, comments,',
    'a back office, a profile, the language chooser), in a container like every other project: on DDEV by default, at https://<name>.ddev.site,',
    'or with `--runtime docker|podman|kubernetes|lando|docksal` on that runtime, at the address the build prints;',
    '`--production` runs it as a live app runs. `bash cmd-tools-symfony-console.sh <name>` says what the app is;',
    '`--run "<console command>"` runs bin/console in it, `--update` updates its packages, `--dev` and `--prod` switch its',
    'environment (the debug toolbar and the profiler are in dev), `--reload-data` loads the demo\'s data again,',
    '`--add-users` adds the default accounts (administrator, user).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Symfony step pack; `--run` runs the suite.',
    `For Symfony work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <app>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run php, composer or bin/console on the host for a project; never write database settings into its .env files by hand.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
