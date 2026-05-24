namespace :audiobook_words do
  desc "Split previously-merged compound word rows (e.g. 'giving.Transactional') into separate sentence-bounded words."
  task split_compounds: :environment do
    affected_chapter_ids = Chapter::Word.unscoped
      .where("text ~ ? OR text ~ ?",
        Chapter::Word::SENTENCE_BREAK.source,
        Chapter::Word::CAMEL_SENTENCE_BREAK.source)
      .distinct.pluck(:chapter_id)

    puts "Found #{affected_chapter_ids.size} chapters with compound words."

    affected_chapter_ids.each do |chapter_id|
      Chapter::Word.transaction do
        rows = Chapter::Word.where(chapter_id:).order(:position).to_a
        atoms = rows.map { |w| { "text" => w.text, "start" => w.start_time_ms / 1000.0, "end" => w.end_time_ms / 1000.0 } }
        expanded = Chapter::Word.split_compound_atoms(atoms)
        next if expanded.size == rows.size

        now = Time.current
        Chapter::Word.where(chapter_id:).delete_all
        Chapter::Word.insert_all!(expanded.map.with_index { |atom, i|
          text = atom["text"]
          {
            chapter_id:,
            text:,
            start_time_ms: (atom["start"] * 1000).round,
            end_time_ms: (atom["end"] * 1000).round,
            position: i,
            orp_index: Chapter::Word.compute_orp_for(text),
            created_at: now,
            updated_at: now
          }
        })
        puts "  chapter #{chapter_id}: #{rows.size} → #{expanded.size} words"
      end
    end
  end
end
