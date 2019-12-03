def swimlane_id
  unless @swimlane
    swimlane_name = @profile.task_configuration['backlog_swimlane_name']
    raise 'review_swimlane_name not configured' unless swimlane_name
    @swimlane = KanboardSwimlane.find_by_name(@profile.project_id, swimlane_name)
    raise "Swimlane #{swimlane_name} not found in project #{@profile.project_id}" unless @swimlane
  end
  return @swimlane.id
end

def column_id(column)
  KanboardColumn.find_by_name(project_id, column).id
end

def create_task_from_redmine(issue, color:, column:)
  issue_title = "RM \##{issue.id}: #{issue.subject}"
  kanboard_task = KanboardTask.create('title' => issue_title,
    'project_id' => @profile.project_id,
    'color_id' => color,
    'description' => issue.description,
    'swimlane_id' => swimlane_id,
    'column_id' => column_id(column))
  kanboard_task.create_redmine_links(issue.url)
  kanboard_task.sync_bugzilla_links
  kanboard_task.sync_github_links
  kanboard_task
end

def create_task_for_manual_sync(issue, pr, column:)
  issue_title = "Assign PR link to the \##{issue.id}"
  description = <<-OUTPUT.gsub(/^\s*/, '')
    Github PR: #{pr.url}
    Redmine issue: #{issue.url}
  OUTPUT
  kanboard_task = KanboardTask.create('title' => issue_title,
    'project_id' => @profile.project_id,
    'color_id' => 'white',
    'description' => description,
    'swimlane_id' => swimlane_id,
    'column_id' => column_id(column))
  kanboard_task.create_link(issue.url, 'Redmine')
  kanboard_task.create_link(pr.url, 'Github PR')
  kanboard_task
end

def create_task_from_gh(pr, column:)
  issue_title = "Can't assign RM issue for \##{pr.url}"
  description = <<-OUTPUT.gsub(/^\s*/, '')
    Github PR: #{pr.url}
    PR title: #{pr.title}
  OUTPUT
  kanboard_task = KanboardTask.create('title' => issue_title,
    'project_id' => @profile.project_id,
    'color_id' => 'Cyan',
    'description' => description,
    'swimlane_id' => swimlane_id,
    'column_id' => column_id(column))
  kanboard_task.create_link(pr.url, 'Github PR')
  kanboard_task
end

default_configuration = {
  'color' => 'yellow',
  'column' => 'In review',
  'github_repos' => []
}

task_configuration = default_configuration.deep_merge(task_configuration)

github_username = @profile.github_options['username']
github_password = @profile.github_options['password']

pr_links = []
issues = []
logger.info "Collecting present PRs and Issues"
project.current_tasks.each do |task|
  pr_links += task.github_links.map(&:url)
  issues += task.redmine_issues.map(&:id)
end

gh = GitHub.new(github_username, github_password)
prs = task_configuration['github_repos'].map { |repo| gh.pulls(repo) }.flatten(1)
task_column = task_configuration['column']

prs.each do |pr|
  unless pr_links.include?(pr.url)
    logger.info "PR #{pr.url} has no related task, importing"
    issue = pr.redmine_issue
    if issue
      if issues.include?(issue.id)
        logger.info "Redmine issue #{issue.id} found and we have task for it. Creating task for manual syncing"
        create_task_for_manual_sync(issue, pr, :column => task_column)
      else
        logger.info "Redmine issue #{issue.id} found. Creating task for it"
        new_task = create_task_from_redmine(issue, :color => task_configuration['color'], :column => task_column)
        pr_links += new_task.github_links.map(&:url) # update the links in case we have more PRs
      end
    else
      logger.info "PR #{pr.title} has no related issue defined, importing to solve"
      create_task_from_gh(pr, :column => task_column)
    end
  end
end
