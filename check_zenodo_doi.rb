require_relative "lib/zenodo_doi_checker"
require_relative "lib/zenodo_doi_message"
require_relative "lib/issue_comment"

issue_id = ENV.fetch("ISSUE_ID")
doi = ENV["ARCHIVE"].to_s.strip
silent_if_not_zenodo = ENV["SILENT_IF_NOT_ZENODO"].to_s.casecmp?("true")

if doi.empty? || doi.casecmp?("pending")
  puts "No archive DOI to check"
  exit(0) if silent_if_not_zenodo
  message = "There's no archive DOI to check yet."
elsif silent_if_not_zenodo && !ZenodoDoiChecker.zenodo_doi?(doi)
  # Archives that aren't in Zenodo (figshare, OSF...) are fine: there's nothing to say about them
  puts "#{doi} isn't a Zenodo DOI, nothing to check"
  exit(0)
else
  message = ZenodoDoiMessage.for(ZenodoDoiChecker.new(doi).check)
end

puts message
exit(1) unless IssueComment.post(issue_id, message)
