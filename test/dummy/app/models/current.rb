class Current < ActiveSupport::CurrentAttributes
  attribute :actor, :impersonator, :download_gate
end
