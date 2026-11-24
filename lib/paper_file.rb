require "date"
require "yaml"

# The metadata of a paper: the YAML front matter of paper.md, or paper.yml for LaTeX papers.
class PaperFile
  attr_accessor :paper_path

  # The contents of the metadata file, when it was read from somewhere other than the
  # local disk (e.g. fetched from a git repository). If not set, metadata_path is read.
  attr_writer :metadata_content

  def initialize(path = nil)
    @paper_path = path
  end

  def metadata
    return {} if paper_path.nil?
    @metadata ||= begin
      content = @metadata_content || File.read(metadata_path)
      # Date and Time are allowed only so that an unquoted date anywhere in the front matter
      # (e.g. `date: 2026-07-06`) doesn't make the whole parse fail; the date itself isn't used.
      YAML.load(content, permitted_classes: [Date, Time], aliases: true)
    rescue StandardError
      {}
    end
    @metadata.is_a?(Hash) ? @metadata : {}
  end

  # List of authors from the paper's metadata as hashes with :name and :orcid keys
  # Supports both `name: Full Name` and the split `given-names`/`surname` fields
  def authors
    raw_authors = metadata["authors"]
    return [] unless raw_authors.is_a?(Array)

    raw_authors.filter_map do |author|
      # Authors can also be listed as plain names: `- Jane Doe`
      author = { "name" => author } if author.is_a?(String)
      next unless author.is_a?(Hash)
      name_fields = author["name"].is_a?(Hash) ? author["name"] : author
      name = if author["name"].is_a?(String)
               author["name"]
             else
               ["given-names", "dropping-particle", "non-dropping-particle", "surname", "suffix"].map { |f| name_fields[f] }.compact.join(" ")
             end
      # Remove footnotes, which can contain brackets: `Jane Doe^[Equal [contribution]]`
      name = name.to_s.gsub(/\^(?<note>\[(?:[^\[\]]|\g<note>)*\])/, "").strip
      next if name.empty?
      { name: name, orcid: author["orcid"].to_s.strip }
    end
  end

  def metadata_path
    if paper_path.end_with?(".tex")
      "#{File.dirname(paper_path)}/paper.yml"
    else
      paper_path
    end
  end
end
