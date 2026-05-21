class Audiobook::Chapter::Card::Review < ApplicationRecord
  self.table_name = "audiobook_chapter_card_reviews"

  belongs_to :card,
    class_name: "Audiobook::Chapter::Card",
    foreign_key: :audiobook_chapter_card_id
end
