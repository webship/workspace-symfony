Feature: The app answers and its accounts work
  As the owner of the app
  I want the blog, the login page and each default account to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change. It is
  # written for the demo application (cmd-symfony-project.sh <name> --demo). The accounts are the
  # default ones (cmd-tools-add-users.sh); a scenario logs in by a handle of the users registry in
  # cucumber.js, so no password is written here.

  @critical
  Scenario: The blog is served
    Given I am an anonymous user
    When I go to "/en/blog/"
    Then the response status code should be 200
    And the navigation should have the item "Search"

  @critical
  Scenario: The login page is served with its form
    Given I am an anonymous user
    When I go to "/en/login"
    Then the response status code should be 200
    And I should see the login form

  Scenario: The administrator logs in and opens the back office
    Given I am a logged in user with the "administrator" user
    When I go to "/en/admin/post/"
    Then I should see "Post List"
    And I should be logged in as "administrator"
    And the navigation should show "Post list" as the current page

  Scenario: The user logs in, and the back office refuses it
    Given I am a logged in user with the "user" user
    Then I should be logged in as "user"
    And the user menu should offer "Account"
    And the navigation should not have the item "Backend"

  Scenario: A page that needs an account sends a visitor to the login form
    Given I am an anonymous user
    When I go to "/en/profile/edit"
    Then I should see the login form
