# frozen_string_literal: true

require "test_helper"
require "open3"

class ReleaseTest < Minitest::Test
  def test_local_publication_is_blocked
    output, error, status = Open3.capture3("bundle", "exec", "rake", "release")
    refute status.success?
    assert_includes output + error, "GitHub Actions publishes"
  end

  def test_shared_release_tasks_are_available
    output, error, status = Open3.capture3("bundle", "exec", "rake", "-T", "release")
    assert status.success?, output + error
    %w[prepare resume tag verify_tag artifact rehearse].each do |task|
      assert_includes output, "release:#{task}"
    end
  end
end
