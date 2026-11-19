Feature: The session of the demo application
  Who may log in, what a refused login says, and the way out.

  Scenario: The administrator logs in with the form and lands on the post list
    Given I am an anonymous user
    When I log in as "administrator" with the login form
    Then I should be on "/en/admin/post/"
    And I should be logged in as "administrator"

  Scenario: A wrong password is refused with the reason, and the username is kept
    Given I am an anonymous user
    When I go to "/en/login"
    And I fill in "Username" with the username of "user"
    And I fill in "Password" with "not-the-right-one"
    And I press "Sign in"
    Then I should see the error message "Invalid credentials."
    And the "Username" field should hold the username of "user"
    And I should not be logged in

  Scenario: A page that needs an account sends a visitor to the login form
    Given I am an anonymous user
    When I go to "/en/profile/edit"
    Then I should see the login form

  Scenario: Logging out ends the session
    Given I am a logged in user with the "user" user
    When I go to "/en/blog/"
    Then the user menu should offer "Account"
    When I log out
    Then I should not be logged in
