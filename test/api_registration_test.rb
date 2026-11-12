# frozen_string_literal: true

require "test_helper"

class ApiRegistrationTest < Minitest::Test
  def test_registration_is_a_noop_without_recording_studio_api
    refute defined?(RecordingStudioApi)
    assert_nil RecordingStudioDownloadable::Api.register_capability_action!
  end

  def test_download_role_matches_html_package_authorization
    assert_equal :view, RecordingStudioDownloadable.configuration.auth_role_for(:download)
    assert_equal :view, RecordingStudioDownloadable::Api.download_role
    assert_equal :view, RecordingStudioDownloadable::Authorization.required_role_for(:download)
    options = { auth_roles: { download: :edit } }
    role = RecordingStudioDownloadable::Authorization.required_role_for(:download, capability_options: options)
    assert_equal :edit, role
  end

  def test_openapi_summaries_are_plain_sentences
    RecordingStudioDownloadable::Api::ACTIONS.each_value do |spec|
      summary = spec.fetch(:summary)

      assert_match(/\A[A-Z].*\.\z/, summary)
      refute_match(/\A[A-Z][a-z]+\z/, summary)
    end
  end
end
