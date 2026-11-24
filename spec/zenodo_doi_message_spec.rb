describe ZenodoDoiMessage do
  describe ".for" do
    describe "version DOIs pass" do
      it "with the version number" do
        message = ZenodoDoiMessage.for(type: :version, doi: "10.5281/zenodo.2", concept_doi: "10.5281/zenodo.1", version: "v1.0", latest: true)
        expect(message).to eq("✅ `10.5281/zenodo.2` is a version DOI (version `v1.0`).")
      end

      it "without a version number if the record has none" do
        message = ZenodoDoiMessage.for(type: :version, doi: "10.5281/zenodo.2", concept_doi: "10.5281/zenodo.1", version: nil, latest: nil)
        expect(message).to eq("✅ `10.5281/zenodo.2` is a version DOI.")
      end

      it "with a note if there's a newer version" do
        message = ZenodoDoiMessage.for(type: :version, doi: "10.5281/zenodo.2", concept_doi: "10.5281/zenodo.1", version: "v1.0", latest: false)
        expect(message).to eq("✅ `10.5281/zenodo.2` is a version DOI (version `v1.0`). Note that there's a newer version of this record.")
      end

      it "even if the record has no concept DOI" do
        message = ZenodoDoiMessage.for(type: :version, doi: "10.5281/zenodo.2", concept_doi: nil, version: nil, latest: nil)
        expect(message).to start_with("✅")
      end
    end

    describe "concept DOIs fail" do
      it "and the latest version's DOI is suggested" do
        message = ZenodoDoiMessage.for(type: :concept, doi: "10.5281/zenodo.1", latest_doi: "10.5281/zenodo.2", version: "v1.0")
        expect(message).to eq("❌ `10.5281/zenodo.1` is a concept DOI, not a version DOI. A concept DOI always resolves to the latest version " +
                              "of the record, so it won't keep pointing to the version that was reviewed." +
                              "\n\nPlease use the DOI of the reviewed version instead. The latest version's DOI is `10.5281/zenodo.2` (version `v1.0`).")
      end

      it "without the latest version's number if it has none" do
        message = ZenodoDoiMessage.for(type: :concept, doi: "10.5281/zenodo.1", latest_doi: "10.5281/zenodo.2", version: nil)
        expect(message).to end_with("The latest version's DOI is `10.5281/zenodo.2`.")
      end
    end

    it "neither passes nor fails DOIs that aren't Zenodo DOIs" do
      expect(ZenodoDoiMessage.for(type: :not_zenodo, doi: "10.21105/joss.01234")).to eq(
        "`10.21105/joss.01234` isn't a Zenodo DOI, so there's nothing to check. Zenodo DOIs look like `10.5281/zenodo.123456`."
      )
    end

    it "fails DOIs with no Zenodo record" do
      expect(ZenodoDoiMessage.for(type: :not_found, doi: "10.5281/zenodo.1")).to eq(
        "❌ I couldn't find a Zenodo record with the DOI `10.5281/zenodo.1`."
      )
    end

    it "neither passes nor fails when Zenodo can't be checked" do
      expect(ZenodoDoiMessage.for(type: :error, doi: "10.5281/zenodo.1")).to eq(
        "I couldn't check `10.5281/zenodo.1` because Zenodo didn't respond as expected. Please try again later."
      )
    end

    it "keeps backticks in the DOI from breaking the formatting" do
      expect(ZenodoDoiMessage.for(type: :not_zenodo, doi: "a`b")).to start_with("`ab` isn't a Zenodo DOI")
    end
  end
end
