require "octokit"
require_relative "lib/authors_check"
require_relative "lib/issue_comment"

# Settings come from the environment (see action.yml), as that's what GitHub actions get.
def list(value)
  value.to_s.split(/[\s,]+/).map { |v| v.sub(/\A@/, "") }.reject(&:empty?)
end

issue_id = ENV.fetch("ISSUE_ID")
repo = ENV.fetch("GH_REPO")
archive_field = ENV["ARCHIVE_FIELD"]

client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"], auto_paginate: true)

check = AuthorsCheck.new(bot_name: ENV["BOT_NAME"].to_s.empty? ? "editorialbot" : ENV["BOT_NAME"],
                         repo: repo,
                         issue_id: issue_id,
                         github_client: client,
                         archive_field: archive_field)

# The archive is the value in the issue: the comments are searched if it's pending
archive_sources = { "issue" => ENV["ARCHIVE"].to_s, "field" => archive_field.to_s }

message = check.run(ENV.fetch("REPOSITORY_URL"), ENV["BRANCH"].to_s, archive_sources, list(ENV["IGNORED_USERS"]), ENV["PAPER"].to_s)

puts message
exit(1) unless IssueComment.post(issue_id, message)
