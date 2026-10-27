# frozen_string_literal: true

# Sibling gems still declare recording_studio below 6. Widen that requirement
# when Bundler loads gemspecs so this app can resolve 6.1.0.
module WidenRecordingStudioRequirement
  def add_dependency(name, *requirements)
    requirements = [">= 6.1.0"] if widen_recording_studio?(name, requirements)

    super
  end

  private

  def widen_recording_studio?(name, requirements)
    return false unless name.to_s == "recording_studio"

    requirements.none? { |requirement| requirement.to_s.include?("6") }
  end
end

unless Gem::Specification.ancestors.include?(WidenRecordingStudioRequirement)
  Gem::Specification.prepend(WidenRecordingStudioRequirement)
end
