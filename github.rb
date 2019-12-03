class GitHub
  GITHUB_API_FQDN = "https://api.github.com"

  attr_reader :connection
  def initialize(username, password)
    @username = username
    @password = password
    @connection = Faraday.new(GITHUB_API_FQDN)
    @connection.basic_auth(username, password) unless username.empty? && password.empty?
  end

  # repo should be in format 'owner/repo'
  def pulls(repo)
    response = @connection.get("/repos/#{repo}/pulls")
    JSON.parse(response.body).map do |pr|
      GithubPr.new(pr)
    end
  end
end
