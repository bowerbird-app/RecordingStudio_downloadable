# frozen_string_literal: true

require_relative "downloadable_test_helper"

class RecordingExtensionTest < ActiveSupport::TestCase
  test "registering the integration twice leaves one recording after_commit" do
    2.times { RecordingStudioDownloadable::Engine.register_recording_studio_integration }
    2.times { RecordingStudio::Engine.apply_model_extensions! }

    callbacks = downloadable_commit_callbacks(RecordingStudio::Recording)

    assert_equal 1, callbacks.size
    assert_equal %i[create update destroy], commit_actions(callbacks.first)
    assert_download_log_association(RecordingStudio::Recording)
    assert_equal 1, downloadable_recording_extensions.size
  end

  test "a reloaded recording class receives the extension once" do
    original = RecordingStudio::Recording
    original_callbacks = downloadable_commit_callbacks(original).size

    apply_recording_extension_twice do |reloaded|
      refute_equal original.object_id, reloaded.object_id
      assert_equal "RecordingStudio::Recording", reloaded.name
      assert_download_log_association(reloaded)
      callbacks = downloadable_commit_callbacks(reloaded)
      assert_equal 1, callbacks.size
      assert_equal %i[create update destroy], commit_actions(callbacks.first)
      assert reloaded.method_defined?(:recording_studio_downloadable_after_commit)
    end
  ensure
    assert_equal original_callbacks, downloadable_commit_callbacks(original).size if original
  end

  private

  def apply_recording_extension_twice
    extension = downloadable_recording_extensions.sole
    configuration = RecordingStudio.configuration
    original_hooks = configuration.instance_variable_get(:@hooks)
    fresh_hooks = RecordingStudio::Hooks.new
    fresh_hooks.model_extensions_for(:recording) << extension
    configuration.instance_variable_set(:@hooks, fresh_hooks)
    original = RecordingStudio::Recording
    reloaded = Class.new(ActiveRecord::Base) { self.table_name = "recording_studio_recordings" }
    RecordingStudio.send(:remove_const, :Recording)
    RecordingStudio.const_set(:Recording, reloaded)
    2.times { RecordingStudio::Engine.apply_model_extensions! }
    yield reloaded
  ensure
    configuration&.instance_variable_set(:@hooks, original_hooks) if original_hooks
    restore_recording_constant(original)
  end

  def restore_recording_constant(original)
    return unless original
    return unless RecordingStudio.const_defined?(:Recording, false)

    RecordingStudio.send(:remove_const, :Recording)
    RecordingStudio.const_set(:Recording, original)
  end

  def downloadable_recording_extensions
    RecordingStudio.configuration.hooks.model_extensions_for(:recording).select do |extension|
      extension.source_location&.first.to_s.end_with?("recording_studio_downloadable/engine.rb")
    end
  end

  def downloadable_commit_callbacks(model)
    model._commit_callbacks.select do |callback|
      callback.filter == :recording_studio_downloadable_after_commit
    end
  end

  def commit_actions(callback)
    seen = nil
    probe = Object.new
    probe.define_singleton_method(:transaction_include_any_action?) do |actions|
      seen = actions
      true
    end
    Array(callback.instance_variable_get(:@if)).each do |condition|
      next unless condition.respond_to?(:lambda?) && condition.lambda?

      probe.instance_exec(&condition)
    end
    seen
  end

  def assert_download_log_association(model)
    association = model.reflect_on_association(:downloadable_download_logs)

    assert association, "expected downloadable_download_logs on #{model.name}"
    assert_equal "RecordingStudioDownloadable::DownloadLog", association.options[:class_name]
    assert_equal :recording, association.options[:inverse_of]
    assert_equal :delete_all, association.options[:dependent]
  end
end
