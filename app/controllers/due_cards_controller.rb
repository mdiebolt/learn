class DueCardsController < ApplicationController
  def index
    @due_cards = Current.user.cards.due
      .includes(:kind, :audiobook_chapter)
      .order(:due)
  end
end
