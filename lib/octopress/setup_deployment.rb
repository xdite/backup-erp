module SetupDeployment
  module ClassMethods
    include Rake::DSL

    def method_missing(m, *args, &block)
      raise "!! No setup method for deplyoment platform `#{m.to_s.sub(/setup_/, '')}` found. Aborting."
    end

    def set_deployment_config(config)
      config = "## Edit this file with `rake config_deploy` ##\n#{config}"
      File.open("deploy.yml", 'w') do |f|
        f.write config
      end
      puts "Configuration written to deploy.yml"
    end

    def setup_rsync
      ssh_user = ask("SSH login", "user@domain.com")
      ssh_port = ask("SSH port", "22")
      document_root = ask("Document root", "~/website.com/")
      delete = ask("When syncing, do you want to delete files in #{document_root} which don't exist locally?", ["y", "n", "help"])
      delete_help <<-DELETE
If you delete on sync:
1. Syncing will create a 1:1 match. Files will be added, updated and deleted from your server's #{document_root} to mirror your local copy.

If you do not delete:
1. You can store files in #{document_root} which aren't found in your local version.
2. Files you have removed from your local site must be removed manually from the server.

Do you want to delete on sync?
      DELETE
      delete = ask(delete_help, ['y','n']) if delete == 'help'

      set_deployment_config <<-CONFIG
method: rsync
ssh_user: #{ssh_user}
ssh_port: #{ssh_port}
document_root: #{document_root}
delete: #{delete === 'y' ? 'true' : 'false'}
      CONFIG
      puts "\n## Now you can deploy to #{ssh_user}:#{document_root} with `rake deploy`. You can avoid entering your password, if your public key is listed in your server's ~/.ssh/authorized_keys file."
    end

    def setup_github
      deploy_dir    = '_deploy'

      # If Github deployment is already set up, read the configuration
      if File.exist?("#{deploy_dir}/.git/config")
        cd deploy_dir do
          @branch = `git branch -a`.match(/\* ([^\s]+)/)[1]
          @repo_url = `git remote -v`.match(/origin\s*(\S+)/)[1]
        end
      else
        # Set up fresh Github deployment
        @repo_url = get_stdin("Configuring for Github's Pages service (http://pages.github.com).\nPlease enter the read/write url for your repository: ")
        @user = @repo_url.match(/:([^\/]+)/)[1]
        @branch = (@repo_url.match(/\/\w+.github.com/).nil?) ? 'gh-pages' : 'master'
        @project = (@branch == 'gh-pages') ? @repo_url.match(/\/([^\.]+)/)[1] : ''

        rm_rf deploy_dir if File.directory?(deploy_dir)
        system "git clone #{@repo_url} #{deploy_dir}"
        puts "## Creating a clean #{@branch} branch for Github pages deployment"
        cd deploy_dir do
          system "git symbolic-ref HEAD refs/heads/#{@branch}"
          system "rm .git/index"
          system "git clean -fdx"
          system "echo 'My Octopress Page is coming soon &hellip;' > index.html"
          system "git add ."
          system "git commit -m \"Octopress init\""
        end
      end
      set_deployment_config <<-CONFIG
method: github
service: #{@branch}
CONFIG
      url = "http://#{user}.github.com"
      url += "/#{project}" unless project == ''
      if self.config['url'].include? 'http://yoursite.com'
        # Set site url in
        jekyll_config = IO.read('_config.yml')
        jekyll_config.sub!(/^url:.*$/, "url: #{url}")
        File.open('_config.yml', 'w') do |f|
          f.write jekyll_config
        end
      end

      # Set root configuration based on deployment type
      if @branch == 'gh-pages'
        subdir = @repo_url.match(/\/([^\.]+)/)[1]
        unless self.config['root'].match("#{subdir}")
          system "rake set_root_dir[#{subdir}]"
        end
      elsif self.config['root'] == '/'
        system "rake set_root_dir[/]"
      end
      puts "\n## Now running `rake deploy` will deploy your generated site to #{url}.\n## If you want to set up a custom domain, follow the guide here: http://octopress.org/docs/deploying/github/#custom_domains\n "
    end


    def setup_heroku
      # Setup
      if `git remote -v`.match(/heroku/).nil?
        if `gem list heroku`.match(/heroku/).nil?
          puts "\nIf you don't have a Heroku Account, create one here: http://heroku.com/signup"
          puts "Install the gem: `gem install heroku`"
        end
        puts "Run `heroku create [subdomain]` to set up a new app on Heroku."
      end
      gitignore = IO.read('.gitignore')
      gitignore.sub!(/^public.*$/, "")
      File.open('.gitignore', 'w') do |f|
        f.write gitignore
      end
      system "git add public" if File.directory?('public')
      set_deployment_config <<-CONFIG
method: github
service: #{@branch}
CONFIG
      puts "Configuration written to deploy.yml"
      puts "\n Commmit then deploy to Heroku using `git push heroku master`"
    end

    def setup_amazon
      service = ask("Choose Amazon service", ['aws', 'cloudfront'])
      set_deployment_config << "method: heroku\nservice: #{service}"
      puts "\n## Now you can deploy to Amazon #{service} with `rake deploy`"
    end
  end
end
