require "open3"

describe "check_zenodo_doi.rb" do
  let(:script) { File.expand_path("../check_zenodo_doi.rb", __dir__) }

  # Runs the script for real, with a fake `gh`. Only for cases that don't reach Zenodo.
  def run_script(env)
    with_fake_gh do |dir|
      full_env = { "PATH" => "#{dir}:#{ENV["PATH"]}", "ISSUE_ID" => "7" }.merge(env)
      stdout, stderr, status = Open3.capture3(full_env, RbConfig.ruby, script)
      yield stdout, stderr, status, posted(dir)
    end
  end

  it "says when the archive isn't a Zenodo DOI" do
    run_script("ARCHIVE" => "10.6084/m9.figshare.123") do |_out, _err, status, body|
      expect(status).to be_success
      expect(body).to eq("`10.6084/m9.figshare.123` isn't a Zenodo DOI, so there's nothing to check. Zenodo DOIs look like `10.5281/zenodo.123456`.")
    end
  end

  it "posts nothing for archives that aren't Zenodo DOIs when silent" do
    run_script("ARCHIVE" => "10.6084/m9.figshare.123", "SILENT_IF_NOT_ZENODO" => "true") do |_out, _err, status, body|
      expect(status).to be_success
      expect(body).to be_nil
    end
  end

  it "says there is nothing to check without an archive, or posts nothing when silent" do
    ["", "Pending"].each do |archive|
      run_script("ARCHIVE" => archive) do |_out, _err, status, body|
        expect(status).to be_success
        expect(body).to eq("There's no archive DOI to check yet.")
      end
      run_script("ARCHIVE" => archive, "SILENT_IF_NOT_ZENODO" => "true") do |_out, _err, status, body|
        expect(status).to be_success
        expect(body).to be_nil
      end
    end
  end

  it "fails if the comment can't be posted" do
    with_fake_gh(exit_status: 1) do |dir|
      env = { "PATH" => "#{dir}:#{ENV["PATH"]}", "ISSUE_ID" => "7", "ARCHIVE" => "10.6084/m9.figshare.123" }
      _out, _err, status = Open3.capture3(env, RbConfig.ruby, script)
      expect(status).to_not be_success
    end
  end
end
