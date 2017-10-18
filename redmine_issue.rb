class RedmineIssue
  attr_reader :url

  def initialize(url)
    @url = url

    response = Faraday.get(@url + '.json')
    @attrs = JSON.parse(response.body)['issue']
  end

  def bugzilla_id
    @attrs['custom_fields'].find { |f| f['name'] == 'Bugzilla link'}['value']
  end

  def bugzilla_link
    "https://bugzilla.redhat.com/show_bug.cgi?id=#{bugzilla_id}"
  end
end