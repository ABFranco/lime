Feature: Track edits to resources

As a database administrator,
For every change I make to an innovation resource through the API (e.g. PUT, POST, PATCH),
I want the API to record this change with a timestamp,
So that I will have a complete history of edits for every resource present.

Background: database already has the following resources

    Given the following resources exist:
      | title                        | url | contact_email | location | types | audiences | desc| population_focuses |
      | Girls in Engineering of California | http://gie.uc.edu |  gie@uc.edu | California | Mentoring,Scholarship | Other | placeholder | Women |
      | Girls in Engineering         | http://gie.berkeley.edu |  gie@berkeley.edu | Berkeley | Mentoring,Scholarship | Other | placeholder | Women |

    Scenario: changing the location of resource Girls in Engineering of California
      When I make a PUT request to "/resources/1" with parameters:
        | location |
        | Turkey |
      When I make a GET request to "/resources" with parameters:
        | location |
        | Turkey |
      Then I should receive a JSON object
      Then the JSON should be empty
