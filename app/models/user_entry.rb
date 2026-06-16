class UserEntry < ApplicationRecord
  include Readable

  belongs_to :user
  belongs_to :entry
end
