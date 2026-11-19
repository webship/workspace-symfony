Feature: The back office of the demo application
  The administrator writes a post, gives it a tag, and deletes it again; a reader is refused.

  Scenario: A post is written, listed on the blog, and deleted through the confirmation dialog
    Given I am a logged in user with the "administrator" user
    When I go to "/en/admin/post/new"
    And I fill in "Title" with "A post of an example scenario"
    And I fill in "Summary" with "A post the example writes and deletes again."
    And I fill in "Content" with "This post was written by an example scenario and is deleted again."
    And I add the tag "lorem" to the "Tags" field
    And I press "Create post"
    Then I should see the success message "Post created successfully!"
    When I go to "/en/blog/"
    Then I should see the post "A post of an example scenario"
    And the post "A post of an example scenario" should have the tag "lorem"
    When I go to "/en/admin/post/"
    And I click "Edit" in the "A post of an example scenario" row
    And I click the "Delete post" button
    And I click "Delete post" in the modal
    Then I should see the success message "Post deleted successfully!"

  Scenario: Content that is too short comes back with the reason under its field
    Given I am a logged in user with the "administrator" user
    When I go to "/en/admin/post/new"
    And I fill in "Title" with "A post of an example scenario"
    And I fill in "Summary" with "A summary."
    And I fill in "Content" with "Too short"
    And I press "Create post"
    Then the "Content" field should have the error "Post content is too short (10 characters minimum)"
    And the "Title" field should have no error

  @js-off
  Scenario: The back office refuses a reader
    Given I am a logged in user with the "user" user
    When I go to "/en/admin/post/"
    Then I should see the 403 error page
