class SearchesController < ApplicationController
  def show
    @query = params[:query]
    yelp_searcher = YelpApiSearcher.new(@query)
  end
end