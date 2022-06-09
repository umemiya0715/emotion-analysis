class Result < ApplicationRecord
  belongs_to :user, optional: true

  # validates :user_id, presence: true
  # validates :dragon_id, presence: true
  # validates :score, presence: true
  # validates :magnitude, presence: true
  # validates :troversion, presence: true
  # validates :target_account, presence: true

  def self.analyzeResult(target, tweets, user)
    require "google/cloud/language"
    client = Google::Cloud::Language.language_service do |config|
      if Rails.env.production?
        config.credentials = JSON.parse(ENV.fetch('GOOGLE_CREDENTIALS'))
      else
        config.credentials = "/Users/umemiyashouta/Downloads/dragon-twitter-analysis.json"
      end
    end
    resultScore = []
    resultMagnitude = []
    tweets.each do |tweet|
      improvedTweet = tweet.text.gsub(/#.*$|[ 　]+|\n|http.*:\/\/t.co\/\w*$/,"")
      document = { type: :PLAIN_TEXT, content: improvedTweet }
      response = client.analyze_sentiment(document: document)
      sentiment = response.document_sentiment
      resultScore.push(sentiment.score)
      resultMagnitude.push(sentiment.magnitude)
    end
    user_id = user
    target_account = target.name
    score = resultScore.sum(0.0) / resultScore.size
    magnitude = resultMagnitude.sum(0.0) / resultMagnitude.size
    troversion = Result.analyzeTroversion(target, tweets)
    dragon_id = Result.whichDragon(score, magnitude, troversion)

    {
      user_id: user_id,
      dragon_id: dragon_id,
      score: score,
      magnitude: magnitude,
      troversion: troversion,
      target_account: target_account
    }
  end

  def self.analyzeTroversion(target, tweets)
    resultFavorites = []
    resultRetweets = []
    tweets.each do |tweet|
      resultFavorites.push(tweet.favorite_count)
      resultRetweets.push(tweet.retweet_count)
    end
    # ツイート頻度
    firstTweetDifference = (Time.now - tweets.last.created_at) / ( 60 * 60 * 24)
    tweetFrequency = tweets.count / firstTweetDifference.floor(2)
    if tweetFrequency <= 2
      userFrequency = tweetFrequency / 2 * 0.2
    elsif
      userFrequency = 0.2
    end
    # リプライ数
    replyRate = ( 5 - tweets.count ) / 5 * 0.2
    # いいね数
    averageFavorites = resultFavorites.sum(0.0) / resultFavorites.size
    if averageFavorites <= 100
      userFavorites = averageFavorites / 100 * 0.2
    elsif
      userFavorites = 0.2
    end
    # フォロワー数
    if target.followers_count <= 1000
      userFollowers = target.followers_count / 1000 * 0.2
    elsif
      userFollowers = 0.2
    end
    # リツイート数
    if resultRetweets.sum(0.0) <= 500
      userRetweets = resultRetweets.sum(0.0) / 500 * 0.2
    elsif
      userRetweets = 0.2
    end
    troversion = userFrequency + replyRate + userFavorites + userFollowers + userRetweets
  end

  def self.whichDragon(score, magnitude, troversion)
    if score >= 0 and magnitude >= 0.5 and troversion >= 0.3
      dragonId = 1
    elsif score >= 0 and magnitude >= 0.5 and troversion < 0.3
      dragonId = 2
    elsif score >= 0 and magnitude < 0.5 and troversion >= 0.3
      dragonId = 3
    elsif score >= 0 and magnitude < 0.5 and troversion < 0.3
      dragonId = 4
    elsif score < 0 and magnitude >= 0.5 and troversion >= 0.3
      dragonId = 5
    elsif score < 0 and magnitude >= 0.5 and troversion < 0.3
      dragonId = 6
    elsif score < 0 and magnitude < 0.5 and troversion >= 0.3
      dragonId = 7
    elsif score < 0 and magnitude < 0.5 and troversion < 0.3
      dragonId = 8
    end
  end
end