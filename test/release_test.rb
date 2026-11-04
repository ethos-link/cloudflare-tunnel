# frozen_string_literal: true

require "test_helper"
require "open3"

class ReleaseTest < Minitest::Test
  def test_release_requires_tag_workflow_instead_of_local_publication
    output, error, status = Open3.capture3("bundle", "exec", "rake", "release")
    refute status.success?
    assert_includes output + error, "GitHub Actions publishes"
  end

  def test_release_verification_accepts_matching_version_and_rejects_mismatched_tag
    output, error, status = Open3.capture3({"RELEASE_TAG" => "v#{Cloudflare::Tunnel::VERSION}"}, "bundle", "exec", "rake", "release:verify")
    assert status.success?, output + error
    output, error, status = Open3.capture3({"RELEASE_TAG" => "v99.0.0"}, "bundle", "exec", "rake", "release:verify")
    refute status.success?
    assert_includes output + error, "Tag and gem version differ"
  end
end
