# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "stringio"

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
  page = Page.find_or_create_by!(title: "Getting Started") do |record|
    record.description = "Seeded dummy page for Attachable upload and Downloadable ZIP smoke."
  end

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)

  press_kit = RecordingStudio::Recording.find_by(
    recordable_type: "PressKit",
    parent_recording_id: root_recording.id,
    trashed_at: nil
  )&.recordable
  press_kit ||= PressKit.find_or_create_by!(name: "Launch Press Kit") do |record|
    record.description = "Photos, copy, and credits for the launch."
    record.credits = "Ava Chen, photos. The Studio, words."
  end
  press_kit_recording = find_or_record_child.call(press_kit, root_recording, root_recording)

  [root_recording, accessible_root_recording, private_root_recording].each do |recording|
    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user)
  end

  stored = RecordingStudioDownloadable::Sources::Attachments.call(press_kit_recording)
  if stored.empty?
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("studio mark"),
      filename: "logo.txt",
      content_type: "text/plain"
    )
    result = press_kit_recording.record_attachment_upload(
      signed_blob_id: blob.signed_id,
      actor: user,
      name: "logo"
    )
    raise "Failed to seed press kit logo" if result.blank?
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Press kit '#{press_kit.name}'"
