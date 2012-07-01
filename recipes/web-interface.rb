#
# Cookbook Name:: graylog2
# Recipe:: web-interface
#
# Copyright 2012, SourceIndex IT-Services
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case node['platform']
when "debian", "ubuntu"
  include_recipe 'apt'
when "centos","redhat"
  include_recipe 'yum'
else
    Chef::Log.warn("The #{node['platform']} is not yet not supported by this cookbook")
end

include_recipe "apache2"
include_recipe "apache2::mod_ssl"
include_recipe "apache2::mod_rewrite"

package "postfix"
package "apache2-dev"
package "libcurl4-openssl-dev"

template "Added Graylog2 Web-Interface Apache config." do
  path "/etc/apache2/sites-available/graylog2"
  source "apache2.erb"
  mode 0644
end

apache_site "000-default" do
  enable false
end

apache_site "graylog2"

group node['graylog2']['web_group'] do
  system true
end

user node['graylog2']['web_user'] do
  home node['graylog2']['web_path']
  gid node['graylog2']['web_group']
  comment "services user for thr graylog2-web-interface"
  supports :manage_home => true
  shell "/bin/bash"
end

unless FileTest.exists?("#{node['graylog2']['web_path']}/graylog2-web-interface-#{node['graylog2']['web_version']}")
  remote_file "#{Chef::Config[:file_cache_path]}/#{node['graylog2']['web_file']}" do
    source node['graylog2']['web_download']
    checksum node['graylog2']['web_checksum']
    action :create_if_missing
  end

  bash "install graylog2 sources #{node['graylog2']['web_file']}" do
    cwd Chef::Config[:file_cache_path]
    code <<-EOH
      tar -zxf #{node['graylog2']['web_file']} -C #{node['graylog2']['web_path']}
    EOH
  end

  link "#{node['graylog2']['web_path']}/current" do
    to "#{node['graylog2']['web_path']}/graylog2-web-interface-#{node['graylog2']['web_version']}"
  end

  log "Downloaded, installed and configured the Graylog2 Web binary files in #{node['graylog2']['web_path']}/#{node['graylog2']['web_version']}." do
    action :nothing
  end
end

template "Create graylog2-web general config." do
  path "#{node['graylog2']['web_path']}/current/config/general.yml"
  source "general.yml.erb"
  owner node['graylog2']['web_user']
  group node['graylog2']['web_group']
  mode 0644
end

template "Create graylog2-web mongodb config." do
  path "#{node['graylog2']['web_path']}/current/config/mongoid.yml"
  source "mongoid.yml.erb"
  owner node['graylog2']['web_user']
  group node['graylog2']['web_group']
  mode 0644
end

template "Create graylog2-web indexer config." do
  path "#{node['graylog2']['web_path']}/current/config/indexer.yml"
  source "indexer.yml.erb"
  owner node['graylog2']['web_user']
  group node['graylog2']['web_group']
  mode 0644
end

template "Create graylog2-web email config." do
  path "#{node['graylog2']['web_path']}/current/config/email.yml"
  source "email.yml.erb"
  owner node['graylog2']['web_user']
  group node['graylog2']['web_group']
  mode 0644
end

node['rvm']['user_installs'] = [
  { 'user' => node['graylog2']['web_user'] }
]

include_recipe "rvm::user_install"

rvm_ruby node['graylog2']['ruby_version'] do
  user node['graylog2']['web_user']
end

rvm_gem "bundler" do
  user node['graylog2']['web_user']
end

rvm_gem "passenger" do
  user node['graylog2']['web_user']
  version node['graylog2']['passenger_version']
end

execute "graylog2-web-interface owner-change" do
    command "chown -Rf #{node['graylog2']['web_user']}:#{node['graylog2']['web_group']} #{node['graylog2']['web_path']}"
end

rvm_shell "passenger module install" do
  user node['graylog2']['web_user']
  group node['graylog2']['web_group']
  creates "#{node['graylog2']['web_path']}/.rvm/gems/#{node['graylog2']['ruby_version']}/gems/passenger-#{node['graylog2']['passenger_version']}/ext/apache2/mod_passenger.so"
  cwd node['graylog2']['web_path']
  code %{passenger-install-apache2-module --auto}
end

rvm_shell "run bundler install" do
  user node['graylog2']['web_user']
  group node['graylog2']['web_group']
  cwd "#{node['graylog2']['web_path']}/current"
  code %{bundle install}
end

cron "Graylog2 send stream alarms" do
  user node['graylog2']['web_user']
  minute node['graylog2']['stream_alarms_cron_minute']
  action node['graylog2']['send_stream_alarms'] ? :create : :delete
  command "source ~/.bashrc && cd #{node['graylog2']['web_path']}/current && RAILS_ENV=production rake streamalarms:send"
end

cron "Graylog2 send stream subscriptions" do
  user node['graylog2']['web_user']
  minute node['graylog2']['stream_subscriptions_cron_minute']
  action node['graylog2']['send_stream_subscriptions'] ? :create : :delete
  command "source ~/.bashrc && cd #{node['graylog2']['web_path']}/current && RAILS_ENV=production rake subscriptions:send"
end

service "apache2" do 
  action :reload
end
