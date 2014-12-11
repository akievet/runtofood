class ApiSearcher
  attr_accessor :address, :distance, :food, :city
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

  def format_address
    lat_long = Geocoder.coordinates(@address)
    lat = lat_long[0]
    long = lat_long[1]
    @address = "#{lat},#{long}"
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

    until @destination_hash != {}
      @random_waypoint_distance = self.get_partial_distances.sample
      hash = Hash[@waypoint_array.map.with_index.to_a]
      #get object with that distance
      @waypoint = @locations[hash[@random_waypoint_distance]]
      #Make google matrix api request again, setting the waypoint as the starting point
      self.google_matrix_response("#{@waypoint.latitude},#{@waypoint.longitude}")
      #Get new set of distances from waypoint to all the other points
      self.get_distances.each_with_index do |distance, index|
        total_route_distance = distance + @random_waypoint_distance
        if total_route_distance > low && total_route_distance < high
          @destination_hash[@locations[index]] = {
            "segment" => distance,
            "total" => total_route_distance
          }
        end
      end
    end
  end

  def get_yelp_results
    self.get_range_distance_matches
    params = {
      term: @food,
      limit: 3,
      radius_filter: 1600
    }

    if @waypoint
      destinations = @destination_hash.keys.select { |key| key.class == Location }
      destinations.map do |destination|
        @yelp_api_results = @yelp_client.search(destination.address, params)
      end
    else
      @destination_hash.keys.map do |destination|
        @yelp_api_results = @yelp_client.search(destination.address, params)
      end
    end
  end

  def get_public_transit_directions(origin, destination)
    output = HTTParty.get("https://maps.googleapis.com/maps/api/directions/json?origin=#{origin}&destination=#{destination}&mode=transit&departure_time=#{Time.now.to_i}&key=#{ENV['GOOGLEAPIKEY']}")
    parse_transit_data(output)
  end

  def parse_transit_data(output)
    route = output["routes"][0]
    copyright = route["copyrights"] || ""
    leg_hash = {}
    route["legs"].map do |leg|
      steps_array = []
      leg_hash["duration"] = leg["duration"]["text"]
      leg["steps"].map do |step|
        step_hash = {}
        step_hash["step_duration"] = step["duration"]["text"],
        step_hash["html_instructions"] = step["html_instructions"],
        if step["transit_details"]
          step_hash["transit_details"] = step["transit_details"]["line"]
        end
        steps_array << step_hash
      end
      leg_hash["steps"] = steps_array
    end
    parsed_data = {
      copyright: copyright,
      legs: leg_hash
    }
  end

  def convert_data
    self.format_address
    @distance = @distance.to_i
  end

  def parse_yelp_results
    self.get_yelp_results
    binding.pry
    restaurants_array = []
    @yelp_api_results.businesses.map do | business |
      hash = {}
      hash["name"] = business.name || ""
      hash["rating"] = business.rating || ""
      hash["url"] = business.url || ""
      hash["latitude"] = business.location.coordinate.latitude || ""
      hash["longitude"] = business.location.coordinate.longitude || ""
      hash["address"] = business.location.display_address || ""
      hash["transit_directions"] = self.get_public_transit_directions(("#{business.location.coordinate.latitude},#{business.location.coordinate.longitude}"),@address) || ""
      if @waypoint
        hash["google_api_input"] = "&origin=#{@address}&waypoints=#{@waypoint.latitude},#{@waypoint.longitude}&destination=#{business.location.coordinate.latitude},#{business.location.coordinate.longitude}&mode=walking"
      else
        hash["google_api_input"] = "&origin=#{@address}&destination=#{business.location.coordinate.latitude},#{business.location.coordinate.longitude}&mode=walking"
      end
      restaurants_array << hash
    end
    return restaurants_array
  end


  def return_destination_info
    self.convert_data
    data_to_send = {
      :starting_point => @address,
      :waypoint => @waypoint || false,
      :businesses => self.parse_yelp_results
    }
  end

end