# frozen_string_literal: true

require_relative "downloadable_test_helper"

class ManifestSourceTest < ActiveSupport::TestCase
  include DownloadableTestHelper
  include ActiveJob::TestHelper

  setup do
    @actor = User.create!(email: "manifest-#{SecureRandom.hex(4)}@example.com", password: "Password",
                          password_confirmation: "Password")
    @recording = create_workspace_recording
    grant_download_access!(@recording, @actor)
  end

  test "source attachments still collects only direct originals" do
    attach_file!(@recording, filename: "direct.txt", contents: "direct", actor: @actor)

    names = @recording.downloadable_files.map(&:filename)

    assert_equal ["direct.txt"], names
    assert_equal :attachments, @recording.downloadable_source
  end

  test "manifest source calls downloadable_manifest on the recordable" do
    called = false
    blob = create_blob!(filename: "hero.jpg", contents: "hero-bytes", content_type: "image/jpeg")
    description = "Hello"
    credits = "Jane Doe"
    json = JSON.pretty_generate({ name: "Kit" })

    @recording.recordable.define_singleton_method(:downloadable_manifest) do
      called = true
      [
        RecordingStudioDownloadable::DownloadFile.from_blob(blob, filename: "hero.jpg"),
        RecordingStudioDownloadable::DownloadFile.from_string(filename: "description.txt", content: description),
        RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: credits),
        RecordingStudioDownloadable::DownloadFile.from_string(
          filename: "press-kit.json",
          content_type: "application/json",
          content: json
        )
      ]
    end

    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      files = @recording.downloadable_files

      assert called
      assert_equal :manifest, @recording.downloadable_source
      assert_equal %w[hero.jpg description.txt credits.txt press-kit.json], files.map(&:filename)
    end
  end

  test "manifest zip contains stored and generated files in order" do
    blob = create_blob!(filename: "ignored.bin", contents: "hero-bytes", content_type: "image/jpeg")
    install_manifest!(
      RecordingStudioDownloadable::DownloadFile.from_blob(blob, filename: "hero.jpg"),
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "description.txt", content: "Hello"),
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: "Jane Doe"),
      RecordingStudioDownloadable::DownloadFile.from_string(
        filename: "press-kit.json",
        content_type: "application/json",
        content: JSON.pretty_generate({ ok: true })
      )
    )

    entries = generated_zip_entries

    assert_equal %w[hero.jpg description.txt credits.txt press-kit.json], entries.keys
    assert_equal "hero-bytes", entries["hero.jpg"]
    assert_equal "Hello", entries["description.txt"]
    assert_equal "Jane Doe", entries["credits.txt"]
    assert_equal JSON.pretty_generate({ ok: true }), entries["press-kit.json"]
  end

  test "empty manifest behaves like empty attachments" do
    install_manifest!

    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      assert_predicate @recording.downloadable_files, :empty?
      assert @recording.downloadable_empty?
      assert_nil @recording.downloadable_generate!
      refute @recording.downloadable_ready?
    end
  end

  test "missing downloadable_manifest raises a downloadable error" do
    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      error = assert_raises(RecordingStudioDownloadable::ManifestMissingError) do
        @recording.downloadable_files
      end

      assert_includes error.message, "downloadable_manifest"
      refute_includes error.message.downcase, "attachments.rb"
    end
  end

  test "invalid manifest entry raises a downloadable error" do
    @recording.recordable.define_singleton_method(:downloadable_manifest) { [Object.new] }

    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      error = assert_raises(RecordingStudioDownloadable::InvalidManifestEntryError) do
        @recording.downloadable_files
      end

      assert_includes error.message, "index 0"
      assert_includes error.message, "Object"
    end
  end

  test "changing generated text makes an existing package stale" do
    credits = +"Jane"
    install_manifest!(
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: credits)
    )

    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      perform_enqueued_jobs { @recording.downloadable_generate! }
      assert @recording.reload.downloadable_ready?

      credits.replace("Jane Doe")
      install_manifest!(
        RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: credits)
      )

      assert @recording.downloadable_stale?
      refute @recording.downloadable_ready?
    end
  end

  test "changing an included blob makes an existing package stale" do
    blob = create_blob!(filename: "hero.jpg", contents: "v1", content_type: "image/jpeg")
    install_manifest!(RecordingStudioDownloadable::DownloadFile.from_blob(blob, filename: "hero.jpg"))

    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      perform_enqueued_jobs { @recording.downloadable_generate! }
      assert @recording.reload.downloadable_ready?

      replacement = create_blob!(filename: "hero.jpg", contents: "v2", content_type: "image/jpeg")
      install_manifest!(RecordingStudioDownloadable::DownloadFile.from_blob(replacement, filename: "hero.jpg"))

      assert @recording.downloadable_stale?
      refute @recording.downloadable_ready?
    end
  end

  test "identical manifest content does not regenerate" do
    install_manifest!(
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: "Jane")
    )

    first = nil
    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      perform_enqueued_jobs { first = @recording.downloadable_generate! }

      install_manifest!(
        RecordingStudioDownloadable::DownloadFile.from_string(filename: "credits.txt", content: "Jane")
      )

      assert_no_enqueued_jobs do
        second = @recording.downloadable_generate!
        assert_equal first.id, second.id
        assert second.ready?
      end
    end
  end

  test "duplicate filenames stay safe through existing zip collision behaviour" do
    install_manifest!(
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "image.jpg", content: "one"),
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "image.jpg", content: "two")
    )

    entries = generated_zip_entries

    assert_equal %w[image.jpg image-2.jpg].sort, entries.keys.sort
    assert_equal "one", entries["image.jpg"]
    assert_equal "two", entries["image-2.jpg"]
  end

  test "unsafe filenames cannot create zip path traversal" do
    install_manifest!(
      RecordingStudioDownloadable::DownloadFile.from_string(filename: "../../secret.txt", content: "nope")
    )

    entries = generated_zip_entries

    assert_equal ["secret.txt"], entries.keys
    refute_includes entries.keys.join, ".."
  end

  private

  def install_manifest!(*files)
    @recording.recordable.define_singleton_method(:downloadable_manifest) { files }
  end

  def generated_zip_entries
    with_downloadable_options(Workspace, source: :manifest, format: :zip) do
      perform_enqueued_jobs { @recording.downloadable_generate! }
      package = @recording.reload.downloadable_package
      zip_entries_from(package.archive.download)
    end
  end
end
