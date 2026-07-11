# == Schema Information
#
# Table name: user_entries
#
#  id         :bigint           not null, primary key
#  read_at    :datetime
#  starred_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  entry_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_entries_on_entry_id                (entry_id)
#  index_user_entries_on_user_id                 (user_id)
#  index_user_entries_on_user_id_and_entry_id    (user_id,entry_id) UNIQUE
#  index_user_entries_on_user_id_and_read_at     (user_id,read_at)
#  index_user_entries_on_user_id_and_starred_at  (user_id,starred_at)
#
# Foreign Keys
#
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (user_id => users.id)
#
class UserEntry < ApplicationRecord
  include Readable

  belongs_to :user
  belongs_to :entry
end
