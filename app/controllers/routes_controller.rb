class RoutesController < ApplicationController
  def index
    address = "40.741061,-73.989699"
    distance = 10
    food = "bagels"
    city = City.find(10)
    searcher = ApiSearcher.new(address, distance, food, city)
    destination_info_array = searcher.return_destination_info
    render json: destination_info_array
  end

end