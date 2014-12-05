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
    @google_matrix_response = HTTParty.get("https://maps.googleapis.com/maps/api/distancematrix/json?origins=#{@address}&destinations=40.807536,-73.962573%7C40.782865,-73.965355%7C40.741061,-73.989699%7C40.746500,-74.001374%7C40.726376,-73.981777%7C40.706876,-74.011265%7C40.717778,-73.957579%7C40.695633,-73.991346%7C40.660204,-73.968956&key=#{ENV['GOOGLEAPIKEY']}&mode=walking")
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