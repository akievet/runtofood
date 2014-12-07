class RoutesController < ApplicationController
  def index
    address = "37.802395,-122.405822"
    distance = 10
    food = "burger"
    city = City.find(12)
    searcher = ApiSearcher.new(address, distance, food, city)
    destination_info_array = searcher.return_destination_info
    render json: destination_info_array
  end

end