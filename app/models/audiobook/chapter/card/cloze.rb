class Audiobook::Chapter::Card::Cloze < ApplicationRecord
  include Kind

  validates :text, :answers, presence: true

  def glyph = "_"

  def segments
    text.split(/(\{\{\d+\}\})/).map do |segment|
      marker = segment.match(/\A\{\{(\d+)\}\}\z/)
      next [ :text, segment ] unless marker
      [ :blank, answers[marker[1].to_i].to_s ]
    end
  end
end
