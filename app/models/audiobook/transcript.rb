class Audiobook::Transcript < ApplicationRecord
  include Scribing

  self.table_name = "audiobook_transcripts"

  belongs_to :audiobook
  has_many :words, class_name: "Audiobook::Transcript::Word",
    foreign_key: :transcript_id, dependent: :destroy

  enum :status, { pending: 0, transcribing: 1, ready: 2, failed: 3 }
end
