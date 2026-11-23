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

  def test_registered_action_names_are_scoped_to_downloadable
    assert_equal %i[downloadable_download downloadable_package_status],
                 RecordingStudioDownloadable::Api::ACTIONS.keys
  end

  def test_openapi_descriptions_are_written_for_api_clients
    download = RecordingStudioDownloadable::Api::ACTIONS.fetch(:downloadable_download)
    status = RecordingStudioDownloadable::Api::ACTIONS.fetch(:downloadable_package_status)

    assert_includes download.fetch(:summary), "POST"
    assert_includes download.fetch(:description), "POST member action"
    assert_includes download.fetch(:description), "state, ready, stale, failed, and failure_message"
    assert_includes download.fetch(:description), "not found"
    assert_includes download.fetch(:description), "download gate"
    assert_includes download.fetch(:description), "rate limit"

    assert_includes status.fetch(:summary), "GET"
    assert_includes status.fetch(:description), "GET member action"
    assert_includes status.fetch(:description), "does not enqueue a build"
    assert_includes status.fetch(:description), "failure_message"
    assert_includes status.fetch(:description), "not found"

    RecordingStudioDownloadable::Api::ACTIONS.each_value do |spec|
      text = "#{spec.fetch(:summary)} #{spec.fetch(:description)}"
      refute_includes text, "download_role"
      refute_includes text, "role"
      refute_includes text, "Request or build"
      refute_includes text, "authorized package route"
    end
  end

  def test_openapi_summaries_are_plain_sentences
    RecordingStudioDownloadable::Api::ACTIONS.each_value do |spec|
      summary = spec.fetch(:summary)

      assert_match(/\A[A-Z].*\.\z/, summary)
      refute_match(/\A[A-Z][a-z]+\z/, summary)
    end
  end
end
