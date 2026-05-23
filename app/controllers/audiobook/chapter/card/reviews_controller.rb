class Audiobook::Chapter::Card::ReviewsController < ApplicationController
  before_action :set_card

  def create
    @card.apply_review!(rating: Integer(review_params.fetch(:rating)))

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def set_card
    audiobook = Current.user.audiobooks.find(params[:audiobook_id])
    chapter = audiobook.chapters.find(params[:chapter_id])
    @card = chapter.cards.where(user: Current.user).find(params[:card_id])
  end

  def review_params
    params.expect(review: [ :rating ])
  end
end
