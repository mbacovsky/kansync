class GithubPr
  GITHUB_API_FQDN = "https://api.github.com"

  def initialize(attrs)
    @attrs = attrs
  end
  # url expecterd in format https://github.com/theforeman/foreman/pull/123
  def self.load(url, username = '', password = '')
    data = url.match /\Ahttps:\/\/github.com\/(.*)\/(.*)\/pull\/(\d+)\Z/
    if data
      owner, repository, pr_number = data[1], data[2], data[3]
    else
      logger.error "Invalid github PR link #{url}, skipping"
      raise "invalid github URL"
    end
    pr_url = "/repos/#{owner}/#{repository}/pulls/#{pr_number}"
    connection = Faraday.new(GITHUB_API_FQDN)
    connection.basic_auth(username, password) unless username.empty? && password.empty?
    response = connection.get(pr_url)
    self.new(JSON.parse(response.body))
  end

  def id
    @attrs.fetch('number')
  end

  def title
    @attrs.fetch('title')
  end

  def redmine_issue
    issue = title.match(/#(\d+)/).try(:[], 1)
    if issue
      RedmineIssue.new(issue)
    else
      nil
    end
  end

  def user
    @attrs.fetch('user').fetch('login')
  end

  def repository
    base_attr('repo').fetch('name')
  end

  def owner
    base_attr('repo').fetch('owner', {})['login']
  end

  def state
    @attrs.fetch('state')
  end

  def opened?
    state == 'open'
  end

  def closed?
    state == 'closed'
  end

  def mergeable?
    @attrs.fetch('mergeable')
  end

  def merged?
    @attrs.fetch('merged')
  end

  def needs_rebase?
    !mergeable? && !merged?
  end

  def labels
    @attrs.fetch('labels', []).map { |label| label['name'] }
  end

  def url
    @attrs.fetch('html_url')
  end

  private

  def head_attr(attr)
    @attrs.fetch('head', {})[attr]
  end

  def base_attr(attr)
    @attrs.fetch('base', {})[attr]
  end
end
