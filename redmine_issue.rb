class RedmineIssue
  attr_reader :url
  REDMINE_URL_FORMAT = "https://projects.theforeman.org/issues/%{redmine_id}"

  def initialize(url_or_id)
    if url_or_id =~ /\A\d+\Z/
      @url = format(REDMINE_URL_FORMAT, redmine_id: url_or_id)
    else
      @url = url_or_id.sub(/\/\Z/, '')
    end

    @url = @url.chomp('/').sub('http://', 'https://')
    response = Faraday.get(@url + '.json')
    @attrs = JSON.parse(response.body)['issue']
  end

  def id
    @attrs.fetch('id')
  end

  def subject
    @attrs.fetch('subject')
  end

  def description
    @attrs.fetch('description')
  end

  def project_name
    name_attr('project')
  end

  def tracker_name
    name_attr('tracker')
  end

  def category_name
    name_attr('category')
  end

  def github_links
    @attrs['custom_fields'].select { |f| f['name'] == 'Pull request' }.first['value']
  end

  def bugzilla
    @bugzilla ||= Bugzilla.new(bugzilla_link) if bugzilla_link
  end

  def bugzilla_id
    @attrs['custom_fields'].find { |f| f['name'] == 'Bugzilla link'}['value']
  end

  def bugzilla_link
    "https://bugzilla.redhat.com/show_bug.cgi?id=#{bugzilla_id}" if bugzilla_id
  end

  def status_id
    @attrs['status']['id'].to_i
  end

  def assigned_to
    name_attr('assigned_to')
  end

  def updated_on
    @attrs['updated_on']
  end

  private
  def name_attr(attr)
    @attrs.fetch(attr, {})['name']
  end
end
