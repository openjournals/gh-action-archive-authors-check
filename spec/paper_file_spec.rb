describe PaperFile do

  subject { described_class.new("./doc/paper.md") }

  describe "#authors" do
    it "should read the authors from the paper's metadata, with YAML aliases, footnotes and plain names" do
      paper = PaperFile.new(fixture("paper_with_authors.md"))
      expect(paper.authors).to eq([{ name: "Jane Q. Doe", orcid: "0000-0001-2345-6789" },
                                   { name: "Ludwig van Beethoven", orcid: "" },
                                   { name: "Grace Hopper", orcid: "" },
                                   { name: "Ada Lovelace", orcid: "" },
                                   { name: "Alan Turing", orcid: "" }])
    end

    it "should be empty if there's no metadata" do
      expect(PaperFile.new.authors).to eq([])
      expect(subject.authors).to eq([])
    end

    def authors_from(yaml)
      PaperFile.new("paper.md").tap { |p| p.metadata_content = yaml }.authors
    end

    it "should be empty without an authors list" do
      expect(authors_from("title: x")).to eq([])
    end

    it "should be empty if authors isn't a list" do
      expect(authors_from("authors: Jane Doe")).to eq([])
      expect(authors_from("authors:\n  name: Jane Doe")).to eq([])
    end

    it "should read authors written as plain names" do
      expect(authors_from("authors:\n  - Jane Doe\n  - John Smith")).to eq([{ name: "Jane Doe", orcid: "" }, { name: "John Smith", orcid: "" }])
    end

    it "should read the name field" do
      expect(authors_from("authors:\n  - name: Jane Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should read split name fields" do
      expect(authors_from("authors:\n  - given-names: Jane\n    surname: Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should read split name fields nested under name" do
      expect(authors_from("authors:\n  - name:\n      given-names: Jane\n      surname: Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should put all name parts in order" do
      yaml = "authors:\n  - surname: Beethoven\n    suffix: Jr.\n    non-dropping-particle: van\n    given-names: Ludwig\n    dropping-particle: de"
      expect(authors_from(yaml)).to eq([{ name: "Ludwig de van Beethoven Jr.", orcid: "" }])
    end

    it "should skip missing name parts" do
      expect(authors_from("authors:\n  - surname: Doe")).to eq([{ name: "Doe", orcid: "" }])
    end

    it "should skip authors without a name" do
      expect(authors_from("authors:\n  - affiliation: 1\n  - name: ''\n  - name: '   '\n  - Jane Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should skip entries that aren't names or fields" do
      expect(authors_from("authors:\n  - 42\n  - \n  - [a, b]\n  - Jane Doe")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should skip names that aren't text" do
      expect(authors_from("authors:\n  - name: 123")).to eq([])
    end

    it "should remove footnotes" do
      expect(authors_from("authors:\n  - name: Jane Doe^[Corresponding author]")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should remove footnotes with brackets" do
      expect(authors_from("authors:\n  - name: Jane Doe^[Equal [contribution] [1]]")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should remove several footnotes" do
      expect(authors_from("authors:\n  - name: Jane^[a] Doe^[b]")).to eq([{ name: "Jane Doe", orcid: "" }])
    end

    it "should keep brackets that aren't footnotes" do
      expect(authors_from("authors:\n  - name: Jane [JD] Doe")).to eq([{ name: "Jane [JD] Doe", orcid: "" }])
    end

    it "should skip names that are only a footnote" do
      expect(authors_from("authors:\n  - name: ^[nobody]")).to eq([])
    end

    it "should strip the ORCID" do
      expect(authors_from("authors:\n  - name: Jane Doe\n    orcid: ' 0000-0001-2345-6789 '")).to eq([{ name: "Jane Doe", orcid: "0000-0001-2345-6789" }])
    end
  end

  describe "#metadata" do
    it "should be empty without a paper" do
      expect(PaperFile.new.metadata).to eq({})
    end

    it "should parse the given content instead of reading the file" do
      paper = PaperFile.new("/does/not/exist/paper.md")
      paper.metadata_content = "title: Given"
      expect(File).to_not receive(:read)
      expect(paper.metadata).to eq({ "title" => "Given" })
    end

    it "should read the paper's file when no content is given" do
      expect(PaperFile.new(fixture("paper_with_authors.md")).metadata["title"]).to eq("Test paper")
    end

    it "should read paper.yml for LaTeX papers" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "paper.yml"), "title: From yml")
        expect(PaperFile.new(File.join(dir, "paper.tex")).metadata).to eq({ "title" => "From yml" })
      end
    end

    it "should only read the front matter of a markdown paper" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "---\ntitle: x\n---\n\n# Summary\n\nText: with: colons"
      expect(paper.metadata).to eq({ "title" => "x" })
    end

    it "should be empty if the file can't be read" do
      expect(PaperFile.new("/does/not/exist/paper.md").metadata).to eq({})
    end

    it "should be empty for invalid YAML" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "title: [unclosed"
      expect(paper.metadata).to eq({})
    end

    it "should be empty if the YAML isn't a map" do
      ["- a\n- b", "just text", ""].each do |content|
        paper = PaperFile.new("paper.md")
        paper.metadata_content = content
        expect(paper.metadata).to eq({})
      end
    end

    it "should allow dates and times" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "date: 2026-07-06\nupdated: 2026-07-06 10:00:00\ntitle: x"
      expect(paper.metadata["title"]).to eq("x")
      expect(paper.metadata["date"]).to eq(Date.new(2026, 7, 6))
    end

    it "should allow YAML aliases" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "a: &x 1\nb: *x"
      expect(paper.metadata).to eq({ "a" => 1, "b" => 1 })
    end

    it "should not create arbitrary objects" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "title: !ruby/object:OpenStruct\n  table: {}"
      expect(paper.metadata).to eq({})
    end

    it "should only parse the content once" do
      paper = PaperFile.new("paper.md")
      paper.metadata_content = "title: x"
      expect(YAML).to receive(:load).once.and_call_original
      2.times { paper.metadata }
    end
  end

end
