# Installs Ruby using the Brightbox Ubuntu repositories.
# https://www.brightbox.com/docs/ruby/ubuntu/

# Workaround for mojolingo/brightbox-ruby-cookbook#5
if node['cdo-ruby']['rubygems_version'].to_f >= 2.2
  node.default['brightbox-ruby']['gems'] -= ['rubygems-bundler']
  gem_package 'rubygems-bundler' do
    action :nothing
  end
end

node.default['brightbox-ruby']['version'] = node['cdo-ruby']['version']
node.default['brightbox-ruby']['rubygems_version'] = node['cdo-ruby']['rubygems_version']
include_recipe 'brightbox-ruby'

# Ensure proper symlinks are set
%w(ruby gem).each{|alt| execute "update-alternatives --force --auto #{alt}" }
