OpenAI.configure do |config|
  # .envファイルから OPENAI_ACCESS_TOKEN を引っ張り出してセットする
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end