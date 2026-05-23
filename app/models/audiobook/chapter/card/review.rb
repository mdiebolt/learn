class Audiobook::Chapter::Card::Review < ApplicationRecord
  RATINGS = {
    again: FsrsRuby::Rating::AGAIN,
    hard:  FsrsRuby::Rating::HARD,
    good:  FsrsRuby::Rating::GOOD,
    easy:  FsrsRuby::Rating::EASY
  }.freeze

  belongs_to :card,
    class_name: "Audiobook::Chapter::Card",
    foreign_key: :audiobook_chapter_card_id
end
