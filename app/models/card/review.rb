class Card::Review < ApplicationRecord
  RATINGS = {
    again: FsrsRuby::Rating::AGAIN,
    hard:  FsrsRuby::Rating::HARD,
    good:  FsrsRuby::Rating::GOOD,
    easy:  FsrsRuby::Rating::EASY
  }.freeze

  belongs_to :card
end
