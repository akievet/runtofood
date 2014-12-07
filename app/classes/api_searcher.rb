class ApiSearcher
  attr_reader :address, :distance, :food, :city
  def initialize(address, distance, food, city)
    @address = address
    @distance = distance
    @food = food
    @city = city
    @yelp_client = Yelp::Client.new({
      consumer_key: ENV['YELPCONSUMERKEY'],
      consumer_secret: ENV['YELPCONSUMERSECRET'],
      token: ENV['YELPTOKEN'],
      token_secret: ENV['YELPTOKENSECRET']
    })
  end

  def google_matrix_response(starting_point)
    @locations = Location.where(city_id: @city.id)
    input = ""
    @locations.each { |location| input << "#{location.latitude},#{location.longitude}%7C"}
    @google_matrix_response = HTTParty.get("https://maps.googleapis.com/maps/api/distancematrix/json?origins=#{starting_point}&destinations=#{input}&key=#{ENV['GOOGLEAPIKEY']}&mode=walking")
  end

  def get_distances
    @distance_array = []
    @google_matrix_response["rows"].first["elements"].each_with_index do |route, index|
      distance = route["distance"]["value"]
      @distance_array << distance
    end
    return @distance_array
  end

  def miles_to_meters(miles)
    miles * 1609.34
  end

  def lower_range_distance
    self.miles_to_meters(@distance) - 1000
  end

  def higher_range_distance
    self.miles_to_meters(@distance) + 1000
  end

  def get_partial_distances
    @waypoint_array = @distance_array.select { |distance| distance < self.lower_range_distance }#all the distances lower than @distance
  end


  def get_range_distance_matches
    low = self.lower_range_distance
    high = self.higher_range_distance
    self.google_matrix_response(@address)
    #destinations = @google_matrix_response["destination_addresses"]
    @destination_hash = {}
    self.get_distances.each_with_index do |distance, index|
      if distance > low && distance < high
        @destination_hash[@locations[index]] = distance
      end
    end

    i = 0
    until @destination_hash.keys > 3 || i == 5
      random_waypoint_distance = self.get_partial_distances.sample
      hash = Hash[@waypoint_array.map.with_index.to_a]
      #get object with that distance
      waypoint = @locations[hash[random_waypoint_distance]]
      @destination_hash["waypoint"] = waypoint
      @destination_hash["waypoint distance"] = random_waypoint_distance
      #Make google matrix api request again, setting the waypoint as the starting point
      self.google_matrix_response("#{waypoint.latitude},#{waypoint.longitude}")
      #Get new set of distances from waypoint to all the other points
      self.get_distances.each_with_index do |distance, index|
        total_route_distance = distance + random_waypoint_distance
        if total_route_distance > low && total_route_distance < high
          @destination_hash[@locations[index]] = {
            "segment" => distance,
            "total" => total_route_distance
          }
        end
      end
      i += 1
    end
  end

  def get_yelp_results
    self.get_range_distance_matches
    params = {
      term: @food,
      limit: 3,
      radius_filter: 1600
    }

    if @destination_hash["waypoint"]
      destinations = @destination_hash.keys.select { |key| key.class == Location }
      destinations.map do |destination|
        @yelp_client.search(destination.address, params)
      end
    else
      @destination_hash.keys.map do |destination|
        @yelp_client.search(destination, params)
      end
    end
  end

  def return_destination_info
    data_to_send = []
    self.get_yelp_results.each_with_index do |area, idx|
      area.businesses.map do |business|
        hash = {}
        hash["name"] = business.name
        hash["rating"] = business.rating
        hash["url"] = business.url
        hash["latitude"] = business.location.coordinate.latitude
        hash["longitude"] = business.location.coordinate.longitude
        hash["address"] = business.location.display_address
        data_to_send << hash
      end
    end
    return data_to_send
  end

end