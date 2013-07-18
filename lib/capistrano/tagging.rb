require 'capistrano'

Capistrano::Configuration.instance(:must_exist).load do
  after  'deploy:restart', 'tagging:deploy'
  before 'deploy:cleanup', 'tagging:cleanup'

  namespace :tagging do
    _cset(:tagging_format, ':rails_env_:release')
    _cset(:tagging_remote, 'origin')
    #_cset(:tagging_environments, %w(production))

    def fetch_or_send(method)
      fetch method, respond_to?(method) ? send(method) : nil
    end

    def tag(options = {})
      fetch(:tagging_format).gsub(/:([a-z_]+[^_:])/i) do |match|
        method = $1.to_sym
        options.fetch method, fetch_or_send(method)
      end
    end

    def remote
      fetch(:tagging_remote)
    end

    def tagging_environment?
      return true if self[:tagging_environments].nil?
      self[:tagging_environments].include?(self[:rails_env])
    end

    def user_name
      `git config --get user.name`.chomp
    end

    def user_email
      `git config --get user.email`.chomp
    end

    def create_tag(name)
      if tagging_environment?
        run_locally "git tag #{name} #{revision} -m \"Deployed by #{user_name} <#{user_email}>\""
        run_locally "git push #{remote} refs/tags/#{name}:refs/tags/#{name}"
      else
        logger.info "ignored git tagging in #{rails_env} environment"
      end
    end

    def remove_tag(name)
      if tagging_environment?
        run_locally "git tag -d #{name}; true"
        run_locally "git push #{remote} :refs/tags/#{name}; true"
      else
        logger.info "ignored git tagging in #{rails_env} environment"
      end
    end

    desc "Create release tag in local and origin repo"
    task :deploy do
      create_tag tag(:release => release_name)
    end

    desc "Remove release tag from local and origin repo"
    task :cleanup do
      count = fetch(:keep_releases, 5).to_i

      if count >= releases.size
        logger.important "no old release tags to clean up"
      else
        logger.info "keeping #{count} of #{releases.size} release tags"
        releases.first(releases.size - count).map do |release|
          remove_tag tag(:release => release)
        end
      end
    end
  end
end
