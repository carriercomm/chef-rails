#
# Cookbook Name:: rails
# Provider:: php_fpm
#
# Copyright (C) 2014 Alexander Merkulov
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Provider.send(:include, Rails::Helpers)

action :create do
  # PHP pools
  if php_fpm?
    template node['php-fpm']['conf_file'] do
      source 'php-fpm.conf.erb'
      cookbook 'php-fpm'
      mode 00644
      owner 'root'
      group 'root'
      notifies :restart, 'service[php-fpm]'
    end

    template "#{node['php']['ext_conf_dir']}/php_fix.ini" do
      owner 'root'
      group 'root'
      mode 00755
      source 'php_fix.erb'
      notifies :restart, 'service[php-fpm]', :delayed
    end

    cleanup_php_fpm

    directory '/var/lib/php/session' do
      owner 'root'
      group 'root'
      mode 00777
    end
  else
    stop_php_fpm
  end

  new_resource.updated_by_last_action(true)
end

action :fix do
  node.default['php-fpm']['skip_repository_install'] = true if rhel?

  new_resource.updated_by_last_action(true)
end

action :configure do
  node['php-fpm']['pools'].each do |pool|
    php_fpm_pool pool[:name] do
      pool.each do |k, v|
        params[k.to_sym] = v
      end
    end
  end

  new_resource.updated_by_last_action(true)
end

# Makers

def cleanup_php_fpm # rubocop:disable Metrics/MethodLength,Metrics/CyclomaticComplexity
  return unless ::Dir.exist? node['php-fpm']['pool_conf_dir']

  ::Dir.foreach(node['php-fpm']['pool_conf_dir']) do |pool|
    next if pool == '.' || pool == '..'
    next unless pool.include?('.conf') && !pool.include?('www.conf')
    next if hash_in_array?(node['php-fpm']['pools'], pool.gsub(/\.conf/, '')) # rubocop:disable Metrics/BlockNesting

    file "#{node['php-fpm']['pool_conf_dir']}/#{pool}" do
      action   :delete
      notifies :restart, 'service[php-fpm]', :delayed
    end
  end
end

def stop_php_fpm
  return unless ::Dir.exist? node['php-fpm']['pool_conf_dir']

  ::Dir.foreach(node['php-fpm']['pool_conf_dir']) do |pool|
    next if pool == '.' || pool == '..'
    next unless pool.include?('.conf') && !pool.include?('www.conf')

    ::File.delete("#{node['php-fpm']['pool_conf_dir']}/#{pool}")
  end
  service 'php-fpm' do
    action [:disable, :stop]
  end
end
