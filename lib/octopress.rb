require 'jekyll'

module Octopress

  # The Octopress configuration is a combination of:
  #
  #   * /config/jekyll.yml - the typical Jekyll _config.yml
  #   * /config/theme.yml  - configures the installed theme, including the plugins it uses
  #   * /config/deploy.yml - deployment configuration
  #
  # The 'Jekyll Way' is to expose all the properties from the configuration as
  # properties of the site object in the views. This remains true, as these
  # configurations are merged. This means that you may do 'site.root', which it
  # a property configured in the deploy.yml file.
  #
  def self.configuration
    @configuration ||=
      YAML.load_file(File.expand_path('../../config/jekyll.yml', __FILE__)).
        deep_merge(YAML.load_file(File.expand_path('../../config/theme.yml', __FILE__))).
        deep_merge(YAML.load_file(File.expand_path('../../config/deploy.yml', __FILE__)))
  end

end
