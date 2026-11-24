require "fileutils"
require "tmpdir"

# A fake `gh` that saves the body of the comment it's asked to post, so the scripts can run for real
module FakeGh
  def with_fake_gh(exit_status: 0)
    Dir.mktmpdir("fake-gh") do |dir|
      File.write(File.join(dir, "gh"), <<~SH)
        #!/bin/bash
        echo "$@" > "#{dir}/args"
        while [ $# -gt 0 ]; do
          if [ "$1" = "--body-file" ]; then cp "$2" "#{dir}/body"; fi
          shift
        done
        exit #{exit_status}
      SH
      FileUtils.chmod(0o755, File.join(dir, "gh"))
      yield dir
    end
  end

  def posted(dir)
    File.exist?("#{dir}/body") ? File.read("#{dir}/body") : nil
  end
end
