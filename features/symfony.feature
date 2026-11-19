Feature: The Symfony plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Symfony builder, each
  AI folder lists the items of its kind the plugin ships, and the Settings page lists the plugin
  with its own page.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "Symfony"
     When I go to "/settings/plugin/symfony"
     Then I should see "@webship.co/workspace-symfony"
      And I should see "cmd-symfony-project.sh"
      And I should see "symfony-site-builder"

  Scenario: A sites folder offers the Symfony builder
    Given I am on "/dev"
     Then "option[value='cmd-symfony-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=symfony-"
     Then I should see "symfony-site-builder"
      And I should see "symfony-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=symfony-scenarios"
     Then I should see "symfony-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=symfony-test"
     Then I should see "symfony-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=symfony-"
     Then I should see "symfony-build-and-test"
      And I should see "symfony-scenarios-for-a-role"
