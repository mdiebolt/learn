class RemembersController < ApplicationController
  def show
    @due_cards = Current.user.cards.due.includes(:kind, :chapter).order(:due)
  end
end
