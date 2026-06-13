class UserEntry < ApplicationRecord
  belongs_to :user
  belongs_to :entry

  scope :read, -> { where.not(read_at: nil) }
  scope :unread, -> { where(read_at: nil) }
  scope :starred, -> { where.not(starred_at: nil) }

  def read?
    read_at.present?
  end

  def starred?
    starred_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def mark_unread!
    update!(read_at: nil) if read?
  end

  def mark_starred!
    update!(starred_at: Time.current) unless starred?
  end

  def mark_unstarred!
    update!(starred_at: nil) if starred?
  end
end
