# frozen_string_literal: true

class AddActionAndExportScopeToRecordingStudioDownloadablePackages < ActiveRecord::Migration[8.1]
  IDENTITY_INDEX = "idx_rs_downloadable_packages_identity"
  LEGACY_INDEX = "idx_rs_downloadable_packages_on_recording_and_format"

  def up
    add_column :recording_studio_downloadable_packages, :action, :string
    add_column :recording_studio_downloadable_packages, :export_scope, :string

    backfill_package_identity!

    change_column_null :recording_studio_downloadable_packages, :action, false
    change_column_null :recording_studio_downloadable_packages, :export_scope, false
    change_column_default :recording_studio_downloadable_packages, :export_scope, from: nil, to: "public"

    remove_index :recording_studio_downloadable_packages, name: LEGACY_INDEX
    add_index :recording_studio_downloadable_packages,
              %i[recording_id action export_scope format],
              unique: true,
              name: IDENTITY_INDEX
  end

  def down
    remove_index :recording_studio_downloadable_packages, name: IDENTITY_INDEX
    add_index :recording_studio_downloadable_packages,
              %i[recording_id format],
              unique: true,
              name: LEGACY_INDEX

    remove_column :recording_studio_downloadable_packages, :action
    remove_column :recording_studio_downloadable_packages, :export_scope
  end

  private

  def backfill_package_identity!
    say_with_time "Backfill downloadable package action and export_scope" do
      recordings = recordings_by_id
      now = quote(Time.current)

      select_rows(
        "SELECT id, recording_id FROM recording_studio_downloadable_packages " \
        "WHERE action IS NULL OR export_scope IS NULL"
      ).each do |id, recording_id|
        recordable_type = recordings[recording_id]
        action = quote(default_action_for(recordable_type))
        execute(<<~SQL.squish)
          UPDATE recording_studio_downloadable_packages
          SET action = COALESCE(action, #{action}),
              export_scope = COALESCE(export_scope, 'public'),
              updated_at = #{now}
          WHERE id = #{quote(id)}
        SQL
      end
    end
  end

  def recordings_by_id
    return {} unless table_exists?(:recording_studio_recordings)

    select_rows("SELECT id, recordable_type FROM recording_studio_recordings").to_h
  end

  def select_rows(sql)
    if connection.respond_to?(:select_rows)
      connection.select_rows(sql)
    else
      exec_query(sql).rows
    end
  end

  def default_action_for(recordable_type)
    return "recordings.download" if recordable_type.to_s.strip.empty?

    key = recordable_type.to_s.underscore.tr("/", "_").pluralize
    "#{key}.download"
  end

  def quote(value)
    connection.quote(value)
  end
end
