Feature: What the framework answers in a live app
  The app runs as a live app runs (cmd-symfony-project.sh <name> --production, or
  cmd-tools-symfony-console.sh <name> --prod): its own error pages, no debug toolbar, forged forms refused.

  @js-off
  Scenario: An address the app does not have answers with the 404 page
    Given I am an anonymous user
    When I go to "/en/no-such-page-of-the-app"
    Then I should see the 404 error page
    And the page should not show debug information

  Scenario: A live app draws no debug toolbar and sends no debug token
    Given I am an anonymous user
    When I go to "/en/blog/"
    Then I should not see the debug toolbar
    And the response should not contain the header "x-debug-token"

  Scenario: A login form sent from another site is refused
    Given I am an anonymous user
    When a page of another site sends a form to "/en/login"
    Then I should see the error message "Invalid CSRF token."

  Scenario: Another language keeps the page and translates it
    Given I am an anonymous user
    When I go to "/en/blog/search"
    And I choose the language "Español"
    Then I should be on "/es/blog/search"
    And the current language should be "Español"
