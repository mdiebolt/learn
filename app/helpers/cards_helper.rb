module CardsHelper
  RATING_HOVERS = {
    again: "hover:text-red-400",
    hard: "hover:text-amber-400",
    good: "hover:text-green-400",
    easy: "hover:text-sky-400"
  }.freeze

def rating_hover_class(rating)
    RATING_HOVERS.fetch(rating.to_sym, "")
  end

  def multiple_choice_card_option_letter(index)
    ("A".ord + index).chr
  end

  def multiple_choice_card_option(index, label)
    tag.button(type: "button", class: "flex min-h-14 w-full items-stretch border border-white/15 text-left transition-colors hover:border-white/40", data: { "cards--multiple-choice_target": "option", "cards--multiple-choice_index_param": index, action: "cards--multiple-choice#choose" }) do
      safe_join([
        tag.span(multiple_choice_card_option_letter(index), class: "flex w-11 shrink-0 items-center justify-center border-r border-white/15 font-mono text-2xs text-white/40"),
        tag.span(label, class: "flex items-center px-4 py-3 text-white/80")
      ])
    end
  end

  def cloze_card_blanks(cloze)
    safe_join(cloze.segments.map { |kind, value| kind == :blank ? cloze_card_blank(value) : value })
  end

  def cloze_card_blank(answer)
    tag.input(type: "text", autocomplete: "off", spellcheck: "false", size: [ answer.length + 1, 5 ].max, class: "cloze-blank", data: { "cards--cloze_target": "blank", answer: })
  end

  def card_actions(submit = nil, reveal: "cards--reveal#show")
    tag.div(class: "flex flex-wrap gap-4", data: { "cards--reveal_target": "controls" }) { safe_join([ submit, reveal_trigger(reveal) ].compact) }
  end

  def submit_button(controller)
    tag.button("[submit]", type: "button", class: "ui-button text-amber-400 hover:text-amber-300", data: { action: "#{controller}#check" })
  end

  def reveal_trigger(action)
    tag.button("[reveal answer]", type: "button", class: "ui-button text-white/40 hover:text-white/70", data: { action: })
  end

  def cloze_card(&block)
    tag.div(class: "space-y-3", data: { controller: "cards--cloze", "cards--cloze_correct_class": "cloze-blank--correct", "cards--cloze_incorrect_class": "cloze-blank--incorrect" }, &block)
  end

  def multiple_choice_card(multiple_choice, &block)
    tag.div(class: "space-y-3", data: { controller: "cards--multiple-choice", "cards--multiple-choice_correct_index_value": multiple_choice.correct_index, "cards--multiple-choice_hover_class": "hover:border-white/40", "cards--multiple-choice_selected_class": "border-amber-400/60 bg-amber-400/10", "cards--multiple-choice_locked_class": "cursor-default", "cards--multiple-choice_correct_class": "border-green-400/60 bg-green-400/10", "cards--multiple-choice_incorrect_class": "border-red-400/60 bg-red-400/10" }, &block)
  end

  def sortable_card(&block)
    tag.div(class: "space-y-3", data: { controller: "cards--sortable", "cards--sortable_dragging_class": "opacity-40", "cards--sortable_grab_class": "cursor-grab", "cards--sortable_locked_class": "cursor-default", "cards--sortable_correct_class": "border-green-400/60 bg-green-400/10", "cards--sortable_incorrect_class": "border-red-400/60 bg-red-400/10" }, &block)
  end

  def sortable_card_list(entries, item_height: "min-h-14")
    tag.ul(class: "space-y-2", data: { "cards--sortable_target": "list", action: "dragover->cards--sortable#dragOver drop->cards--sortable#drop" }) { safe_join(entries.map { |label, position| sortable_card_item(label, position, height: item_height) }) }
  end

  def sortable_card_item(label, position, height: "min-h-14")
    tag.li(class: "flex #{height} cursor-grab items-center gap-3 border border-white/15 px-3 py-2 text-white/80 transition-colors", draggable: true, data: { "cards--sortable_target": "item", position:, action: "dragstart->cards--sortable#dragStart dragend->cards--sortable#dragEnd" }) { safe_join([ tag.span("::", class: "font-mono text-2xs text-white/30"), tag.span(label) ]) }
  end
end
