#
# Cookbook Name:: dmg
# Provider:: package
#
# Copyright 2011, Joshua Timberman
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

def load_current_resource
  @dmgpkg = Chef::Resource::DmgPackage.new(new_resource.name)
  @dmgpkg.app(new_resource.app)
  Chef::Log.debug("Checking for application #{new_resource.app}")
  installed = ::File.directory?("#{new_resource.destination}/#{new_resource.app}.app")
  @dmgpkg.installed(installed)
end

action :install do
  unless @dmgpkg.installed

    volumes_dir = new_resource.volumes_dir ? new_resource.volumes_dir : new_resource.app
    dmg_name = new_resource.dmg_name ? new_resource.dmg_name : new_resource.app
    dmg_file = "#{Chef::Config[:file_cache_path]}/#{dmg_name}.dmg"

    if new_resource.source
      remote_file dmg_file do
				Chef::Log.debug("source:  #{new_resource.source}")
        source new_resource.source
        checksum new_resource.checksum if new_resource.checksum
      end
    end

    execute "hdid '#{dmg_file}'" do
      not_if "hdiutil info | grep -q 'image-path.*#{dmg_file}'"
    end

		if new_resource.package
			# dmg w/pkg
			package_extension = "pkg"
			pkg_root = "/Volumes/#{volumes_dir}"
			available_packages = Dir["#{pkg_root}/**/*#{package_extension}"]
			Chef::Log.debug("DMG package root: #{pkg_root}")
			Chef::Log.debug("DMG available packages:  #{available_packages.join(', ')}")
			target_package = available_packages.detect do |package_filename| 
				::File.basename(package_filename) == new_resource.package
			end

			raise "#{new_resource.package} not among available packages #{available_packages.join(', ')}" unless target_package
			package_path = ::File.expand_path(target_package)
			Chef::Log.debug("Installing #{package_path}")
			execute "installer -pkg '#{package_path}' -target '/' -verbose "
		else
			#dmg w/ .app
			execute "cp -R '/Volumes/#{volumes_dir}/#{new_resource.app}.app' '#{new_resource.destination}'"

			file "#{new_resource.destination}/#{new_resource.app}.app/Contents/MacOS/#{new_resource.app}" do
				mode 0755
			end
		end
    execute "hdiutil detach '/Volumes/#{volumes_dir}'"
  end
end
