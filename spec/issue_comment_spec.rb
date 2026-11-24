describe IssueComment do
  around do |example|
    path = ENV["PATH"]
    example.run
    ENV["PATH"] = path
  end

  it "posts the body with the GitHub CLI in the given issue" do
    with_fake_gh do |dir|
      ENV["PATH"] = "#{dir}:#{ENV["PATH"]}"
      expect(IssueComment.post(12, "Hello\n\n`@user`")).to be(true)
      expect(File.read("#{dir}/args")).to start_with("issue comment 12 --body-file")
      expect(posted(dir)).to eq("Hello\n\n`@user`")
    end
  end

  it "returns false when GitHub CLI fails" do
    with_fake_gh(exit_status: 1) do |dir|
      ENV["PATH"] = "#{dir}:#{ENV["PATH"]}"
      expect { expect(IssueComment.post(12, "Hello")).to be(false) }.to output.to_stderr
    end
  end
end
