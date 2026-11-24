require "ostruct"
require "rspec"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

lib = File.expand_path("../lib", __dir__)
%w[authors_checker authors_check paper_file repo_metadata zenodo_doi_checker zenodo_doi_message issue_comment].each do |file|
  require File.join(lib, file)
end

module Fixtures
  def fixture(file_name)
    File.join(__dir__, "support", "fixtures", file_name)
  end
end

RSpec.configure { |config| config.include Fixtures }

require_relative "support_gh"
RSpec.configure { |config| config.include FakeGh }
