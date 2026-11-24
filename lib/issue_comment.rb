require "open3"
require "tempfile"

# Posts a comment in the review issue with the GitHub CLI, which uses the GITHUB_TOKEN and
# GH_REPO env vars (the token of the user posting the results and the repository of the issue).
module IssueComment
  module_function

  # Returns true if the comment was posted
  def post(issue_id, body)
    Tempfile.create(["comment", ".md"]) do |file|
      file.write(body)
      file.flush
      _stdout, stderr, status = Open3.capture3("gh", "issue", "comment", issue_id.to_s, "--body-file", file.path)
      warn(stderr) unless status.success?
      status.success?
    end
  end
end
