class TestingRepoMetadata
  include RepoMetadata
end

describe RepoMetadata do
  subject { TestingRepoMetadata.new }

  describe "#clone_repo_metadata" do
    let(:base) { ["git", "clone", "--quiet", "--depth", "1", "--filter=blob:none", "--no-checkout"] }

    it "should do a shallow clone without file contents" do
      expect(Open3).to receive(:capture3).with(*base, "--", "https://github.com/a/b", "./local/folder").
                       and_return(["", "", OpenStruct.new(success?: true)])
      expect(subject.clone_repo_metadata("https://github.com/a/b", "./local/folder")).to be_truthy
    end

    it "should clone the given branch" do
      expect(Open3).to receive(:capture3).with(*base, "--branch", "joss/paper", "--", "https://github.com/a/b", "./local/folder").
                       and_return(["", "", OpenStruct.new(success?: false)])
      expect(subject.clone_repo_metadata("https://github.com/a/b", "./local/folder", "joss/paper")).to be_falsy
    end

    it "should reject invalid urls and branch names" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.clone_repo_metadata("file:///etc/passwd", "./local/folder")).to be_falsy
      expect(subject.clone_repo_metadata("https://github.com/a/b", "./local/folder", "--upload-pack=x")).to be_falsy
    end
  end

  describe "#repo_files and #read_repo_file" do
    it "should list the regular files, skipping symlinks and submodules, and read one" do
      tree = "100644 blob aaa\ta.md\0" \
             "100755 blob bbb\tbin/run\0" \
             "120000 blob ccc\tpaper.md\0" \
             "160000 commit ddd\tvendor/lib\0" \
             "100644 blob eee\tpaper/paper.md\0"
      expect(Open3).to receive(:capture3).with("git", "-C", "./repo", "ls-tree", "-r", "-z", "HEAD").
                       and_return([tree, "", OpenStruct.new(success?: true)])
      expect(subject.repo_files("./repo")).to eq(["a.md", "bin/run", "paper/paper.md"])

      expect(Open3).to receive(:capture3).with("git", "-C", "./repo", "show", "HEAD:paper/paper.md").
                       and_return(["content", "", OpenStruct.new(success?: true)])
      expect(subject.read_repo_file("./repo", "paper/paper.md")).to eq("content")
    end

    it "should return empty values on errors" do
      allow(Open3).to receive(:capture3).and_return(["", "fatal", OpenStruct.new(success?: false)])
      expect(subject.repo_files("./repo")).to eq([])
      expect(subject.read_repo_file("./repo", "missing.md")).to be_nil
    end
  end

  describe "#clone_repo_metadata (more cases)" do
    let(:base) { ["git", "clone", "--quiet", "--depth", "1", "--filter=blob:none", "--no-checkout"] }
    let(:ok) { ["", "", OpenStruct.new(success?: true)] }

    it "accepts http urls" do
      expect(Open3).to receive(:capture3).with(*base, "--", "http://example.com/a/b", "./f").and_return(ok)
      expect(subject.clone_repo_metadata("http://example.com/a/b", "./f")).to be true
    end

    it "rejects urls without a host and missing urls" do
      expect(Open3).to_not receive(:capture3)
      expect(subject.clone_repo_metadata("https:/a/b", "./f")).to be false
      expect(subject.clone_repo_metadata(nil, "./f")).to be false
      expect(subject.clone_repo_metadata("not a url", "./f")).to be false
    end

    it "doesn't pass a branch when it's blank" do
      expect(Open3).to receive(:capture3).with(*base, "--", "https://github.com/a/b", "./f").twice.and_return(ok)
      subject.clone_repo_metadata("https://github.com/a/b", "./f", nil)
      subject.clone_repo_metadata("https://github.com/a/b", "./f", "   ")
    end

    it "strips the branch name" do
      expect(Open3).to receive(:capture3).with(*base, "--branch", "joss", "--", "https://github.com/a/b", "./f").and_return(ok)
      subject.clone_repo_metadata("https://github.com/a/b", "./f", " joss ")
    end

    it "rejects branch names that aren't safe" do
      expect(Open3).to_not receive(:capture3)
      ["-x", "a b", "a;b", "$(x)"].each do |branch|
        expect(subject.clone_repo_metadata("https://github.com/a/b", "./f", branch)).to be false
      end
    end

    it "creates the folder before cloning" do
      allow(Open3).to receive(:capture3).and_return(ok)
      expect(FileUtils).to receive(:mkdir_p).with("./f")
      subject.clone_repo_metadata("https://github.com/a/b", "./f")
    end
  end

  describe "#repo_files (more cases)" do
    def tree(output, success: true)
      allow(Open3).to receive(:capture3).and_return([output, "", OpenStruct.new(success?: success)])
    end

    it "is empty if git fails" do
      tree("100644 blob a\tx.md\0", success: false)
      expect(subject.repo_files("./repo")).to eq([])
    end

    it "is empty for an empty repository" do
      tree("")
      expect(subject.repo_files("./repo")).to eq([])
    end

    it "keeps tabs in file names" do
      tree("100644 blob a\tweird\tname.md\0")
      expect(subject.repo_files("./repo")).to eq(["weird\tname.md"])
    end

    it "skips malformed entries" do
      tree("garbage\x00100644 blob a\tok.md\0")
      expect(subject.repo_files("./repo")).to eq(["ok.md"])
    end

    it "returns binary paths, so names that aren't UTF-8 can be compared" do
      tree("100644 blob a\tr\xE9sum\xE9/paper.md\0".b)
      paths = subject.repo_files("./repo")
      expect(paths.first.encoding).to eq(Encoding::BINARY)
      expect(paths.first).to end_with("/paper.md")
    end
  end

  describe "#read_repo_file (more cases)" do
    it "passes paths that aren't UTF-8 to git" do
      expect(Open3).to receive(:capture3).with("git", "-C", "./repo", "show", "HEAD:r\xE9sum\xE9.md".b).
                       and_return(["x", "", OpenStruct.new(success?: true)])
      expect(subject.read_repo_file("./repo", "r\xE9sum\xE9.md".b)).to eq("x")
    end

    it "returns UTF-8 content, replacing invalid bytes" do
      allow(Open3).to receive(:capture3).and_return(["caf\xE9".b, "", OpenStruct.new(success?: true)])
      content = subject.read_repo_file("./repo", "paper.md")
      expect(content.encoding).to eq(Encoding::UTF_8)
      expect(content).to be_valid_encoding
      expect(content).to start_with("caf")
    end

    it "keeps valid UTF-8 content as is" do
      allow(Open3).to receive(:capture3).and_return(["José".b, "", OpenStruct.new(success?: true)])
      expect(subject.read_repo_file("./repo", "paper.md")).to eq("José")
    end
  end

end
