class Card::ReviewsController < ApplicationController
  before_action :set_card

  def create
    @card.review!(rating: Integer(review_params.fetch(:rating)))

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:card_id])
  end

  def review_params
    params.expect(review: [ :rating ])
  end
end
