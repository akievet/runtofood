class ApiSearcher
  def initialize()
    @yelp_consumer_key = ENV['YELP_CONSUMER_KEY']
    @yelp_consumer_secret = ENV['YELP_CONSUMER_SECRET']
    @yelp_token = ENV['YELP_TOKEN']
    @yelp_token_secret = ENV['YELP_TOKEN_SECRET']
    @google_api_key = ENV['GOOGLE_API_KEY']
  end

  def setup_yelp_client
    @client = Yelp::Client.new({
      consumer_key: @yelp_consumer_key,
      consumer_secret: @yelp_consumer_secret,
      token: @yelp_token,
      token_secret: @yelp_token_secret
    })
  end
end