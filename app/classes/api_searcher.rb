class ApiSearcher
  attr_reader :address, :distance, :food
  def initialize(address, distance, food)
    @address = address
    @distance = distance
    @food = food
    @yelp_client = Yelp::Client.new({
      consumer_key: ENV['YELPCONSUMERKEY'],
      consumer_secret: ENV['YELPCONSUMERSECRET'],
      token: ENV['YELPTOKEN'],
      token_secret: ENV['YELPTOKENSECRET']
    })
  end

  def google_matrix_response
    financial_district = "40.707491,-74.011276"
    greenwich_village = "40.733572,-74.002742"
    essex = "40.718448,-73.988241"
    hudson_yards = "40.754265,-74.003118"
    murray_hill = "40.747879,-73.975657"
    uws = "40.787011,-73.975368"
    ues = "40.773565,-73.956555"
    morningside_heights = "40.808956,-73.962433"
    wash_heights = "40.841708,-73.939355"
    carrol_garderns = "40.679533,-73.999164"
    clinton_hill = "40.689367,-73.963902"
    park_slope = "40.668104,-73.980582"
    williamsburg = "40.708116,-73.957070"
    greenpoint = "40.724545,-73.941860"
    long_island_city = "40.744679,-73.948542"
    astoria = "40.764357,-73.923462"

    @google_matrix_response = HTTParty.get("https://maps.googleapis.com/maps/api/distancematrix/json?origins=#{@address}&destinations=#{financial_district}%7C#{greenwich_village}%7C#{essex}%7C#{hudson_yards}%7C#{murray_hill}%7C#{uws}%7C#{ues}%7C#{morningside_heights}%7C#{wash_heights}%7C#{carrol_garderns}%7C#{clinton_hill}%7C#{park_slope}%7C#{williamsburg}%7C#{greenpoint}%7C#{long_island_city}%7C#{astoria}&key=#{ENV['GOOGLEAPIKEY']}&mode=walking")
  end

  def get_distances
    distance_array = []
    @google_matrix_response["rows"].first["elements"].each_with_index do |route, index|
      distance = route["distance"]["value"]
      distance_array << distance
    end
    return distance_array
  end

  def miles_to_meters(miles)
    miles * 1609.34
  end

  def lower_range_distance
    self.miles_to_meters(@distance) - 1000
  end

  def higher_range_distance
    self.miles_to_meters(@distance) + 100
  end


  def get_range_distance_matches
    low = self.lower_range_distance
    high = self.higher_range_distance
    self.google_matrix_response
    destinations = @google_matrix_response["destination_addresses"]
    destination_hash = {}
    self.get_distances.each_with_index do |distance, index|
      if distance > low && distance < high
        destination_hash["#{destinations[index]}"] = distance
      end
    end
    return destination_hash
  end

  def get_yelp_results
    params = {
      term: @food,
      limit: 3,
      radius_filter: 1600
    }
    self.get_range_distance_matches.keys.map do |destination|
      @yelp_client.search(destination, params)
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