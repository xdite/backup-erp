# Polyfill for __method__ for Ruby versions older than 1.9
__method__ ||= lambda do
  caller[0] =~ /`([^']*)'/ and $1
end.call


module SetupDeployment
  module ClassMethods
    include Rake::DSL

    def method_missing(m, *args, &block)
      raise "!! No setup method for deplyoment platform `#{m.to_s.sub(/setup_/, '')}` found. Aborting."
    end

    def set_deployment_config(deploy_config)
      jekyll_config = IO.read('_config.yml')
      if /^deploy_config:.*$/ =~ jekyll_config
        jekyll_config.sub!(/^deploy_config:.*$/, "deploy_config: #{deploy_config}")
      else
        jekyll_config << <<-CONFIG

# ----------------------- #
#       Deployment        #
# ----------------------- #

deploy_config: #{deploy_config}
        CONFIG
      end
      File.open('_config.yml', 'w') { |f| f.write jekyll_config }

      puts "## Deployment configured in #{deploy_config}.yml."
    end


    def setup_rsync
      deploy_config = __method__.to_s.sub('setup_', '')

      ssh_user = ask("SSH login", "user@domain.com")
      ssh_port = ask("SSH port", "22")
      document_root = ask("Document root", "~/website.com/")
      delete = ask("When syncing, do you want to delete files in #{document_root} which don't exist locally?", ["y", "n", "help"])
      delete_help <<-DELETE
If you delete on sync:
1. The server will create update and delete files to match your local version.
2. When you remove a page, it will be removed from the server.
3. Any files in your #{document_root} that aren't in your local copy will be removed, including files you may have uploaded via SFTP.

If you do not delete:
1. You can store files in #{document_root} which aren't found in your local version
2. Files you have removed from your local site must be removed manually from the server

Do you want to delete on sync?
      DELETE
      delete = ask(delete_help, ['y','n']) if delete == 'help'

      File.open("#{deploy_config}.yml", 'w') do |f|
        f.write <<-CONFIG
ssh_user: #{ssh_user}
ssh_port: #{ssh_port}
document_root: #{document_root}
delete: #{delete === 'y' ? 'true' : 'false'}
        CONFIG
      end
      set_deployment_config(deploy_config)
      puts "\n## Now you can deploy to #{ssh_user}:#{document_root} with `rake deploy`. You can avoid entering your password, if your public key is listed in your server's ~/.ssh/authorized_keys file."
    end

    def setup_github
      deploy_config = __method__.to_s.sub('setup_', '')
      deploy_dir    = '_deploy'

      # If Github deployment is already set up, read the configuration
      if File.exist?("#{deploy_dir}/.git/config")
        cd deploy_dir do
          @branch = `git branch -a`.match(/\* ([^\s]+)/)[1]
          @repo_url = `git remote -v`.match(/origin\s*(\S+)/)[1]
        end

      # Set up fresh Github deployment
      else
        @repo_url = get_stdin("To use Github's Pages service (http://pages.github.com) please enter the read/write url for your repository: ")
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
      File.open("#{deploy_config}.yml", 'w') do |f|
        f.write <<-CONFIG
deploy_branch: #{@branch}
deploy_dir: #{deploy_dir}
CONFIG
      end
      set_deployment_config(deploy_config)

      # Set root configuration based on deployment type
      if @branch == 'gh-pages'
        subdir = @repo_url.match(/\/([^\.]+)/)[1]
        unless self.config['root'].match("#{subdir}")
          system "rake set_root_dir[#{subdir}]"
        end
      elsif self.config['root'] == '/'
        system "rake set_root_dir[/]"
      end
      puts "\n## Now running `rake deploy` will deploy your generated site to #{@repo_url} #{@branch}"
    end


    def setup_heroku
      # Setup
      if `git remote -v`.match(/heroku/).nil?
        if `gem list heroku`.match(/heroku/).nil?
          puts "\nIf you don't have a Heroku Account, create one: http://heroku.com/signup"
          puts "Install the Heroku gem: `gem install heroku`"
        end
        puts "Run `heroku create` to set up a new app on Heroku."
      end
      gitignore = IO.read('.gitignore')
      gitignore.sub!(/^public.*$/, "")
      File.open('.gitignore', 'w') do |f|
        f.write gitignore
      end
      system "git add public" if File.directory?('public')
      puts "\n Commmit then deploy to Heroku using `git push heroku master`"
      deploy_config = __method__.to_s.sub('setup_', '')
      set_deployment_config(deploy_config)
    end

    def setup_amazon
      deploy_config = __method__.to_s.sub('setup_', '')
      service = ask("Choose Amazon service", ['aws', 'cloudfront'])

      File.open("#{deploy_config}.yml", 'w') { |f| f.write "service: #{service}" }
      set_deployment_config(deploy_config)
      puts "\n## Now you can deploy to #{service} with `rake deploy`"
    end

  end
end
