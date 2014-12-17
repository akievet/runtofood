class RoutesController < ApplicationController
  def index
    if params[:city]
      city = City.find(params[:city])
      city_string = city.name
      address = "#{params[:address]}, #{city_string}"
      food = params[:food]
      distance = params[:distance]
    else
      city = City.find(1)
      address = "505 LaGuardia Pl, NYC"
      food = "bagels"
      distance = 4
    end
    searcher = ApiSearcher.new(address, distance, food, city)
    destination_info_array = searcher.return_destination_info
    render json: destination_info_array
  end

end