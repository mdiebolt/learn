module Upload::Chapter::WordProcessing
  extend ActiveSupport::Concern

  def preprocess_words!
    self.words = content.split(/\s+/).map.with_index do |word, index|
      recognition_point = optimal_recognition_point_for(word)
      {
        index: index,
        word: word,
        optimal_recognition_point: recognition_point,
        focal_character: word[recognition_point]
      }
    end
    save!
  end

  private

  def optimal_recognition_point_for(word)
    clean = word.gsub(/[^a-zA-Z]/, "")
    length = clean.length

    base_position = case length
                    when 0..1 then 0
                    when 2..5 then 1
                    when 6..9 then 2
                    when 10..13 then 3
                    else 4
                    end

    leading_punctuation_length = word.match(/^[^a-zA-Z]*/)[0].length
    [base_position + leading_punctuation_length, word.length - 1].min
  end
end
