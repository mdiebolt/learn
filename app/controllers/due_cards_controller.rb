class DueCardsController < ApplicationController
  def index
    @due_cards = Current.user.cards.due.includes(:kind, :chapter).order(:due)
  end
end
