class RedmineIssue
  attr_reader :url
  REDMINE_URL_FORMAT = "https://projects.theforeman.org/issues/%{redmine_id}"
  REDMINE_URL_PATTERN = %r{https://projects.theforeman.org/issues/\d+}

  def initialize(url_or_id)
    if url_or_id =~ /\A\d+\Z/
      @url = format(REDMINE_URL_FORMAT, redmine_id: url_or_id)
    else
      url = url_or_id.match(REDMINE_URL_PATTERN)
      raise "Invalid RM #{url_or_id}" unless url
      @url = url[0]
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
    links = @attrs['custom_fields'].find{ |f| f['name'] == 'Pull request' }
    links ? links['value'] : []
  end

  def bugzilla
    @bugzilla ||= Bugzilla.load(bugzilla_link) if bugzilla_link
  end

  def bugzilla_id
    link = @attrs['custom_fields'].find { |f| f['name'] == 'Bugzilla link'}
    link ? link['value'] : nil
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

  def triaged
    # Triaged here means the RM issue was triaged and moved Kanboard
    # currently we try to use team backlog field but may be simplier to have some dedicated bool field
    # the original version tried to use Triaged field but currently Triaged != On KB backlog
    # TODO update when we find out how to indicate that in the issue
    # @attrs['custom_fields'].find { |cf| cf['name'] == 'Triaged' }['value'] == '1'
    true
  end

  def triaged=(value)
    # TODO
  end

  private
  def name_attr(attr)
    @attrs.fetch(attr, {})['name']
  end
end
