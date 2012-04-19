#
# Cookbook Name:: graylog2
# Recipe:: apache2
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

include_recipe "apache2"
include_recipe "apache2::mod_ssl"
include_recipe "apache2::mod_rewrite"

package "libapache2-mod-passenger"

template "apache-vhost-conf" do
  path "/etc/apache2/sites-available/graylog2"
  source "graylog2.apache2.erb"
  mode 0644
end

apache_site "000-default" do
  enable false
end

apache_site "graylog2"
