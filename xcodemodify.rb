#!/usr/bin/ruby

require 'xcodeproj'
require 'json'

module XcodeModify
	class XCProject

		def  initialize(project_path, target_name = '', xcmod_path)
			@project = Xcodeproj::Project.open(project_path)
			if target_name.empty?
				@target = @project.targets.first
			else
				for target in @project.targets do
					if target.name.eql?(target_name)
						@target = target
						break;
					end
				end
			end
			if xcmod_path
				xcmod_file = File.read(xcmod_path)
				@xcmod = JSON.parse(xcmod_file)
			end
			@embed_binaries = Array.new
			@copy_files_build_phase = nil
			@modify_with_copy = false
			@release_dir_name = "IOS"
		end

		def is_source_file(name)
			name.end_with?(".m", ".mm", ".swift", ".c", ".cpp")
		end

		def  is_binary_library(name)
			name.end_with?(".framework", ".a", ".tbd", ".dylib")
		end

		def is_head_file(name)
			name.end_with?(".h")
		end

		def  is_resource(name)
			if  !is_source_file(name) && !is_head_file(name) && !is_binary_library(name) && !is_excludes(name)
				true
			else
				false
			end
		end

		def is_excludes(name)
			if name.index(".") == 0
				true
			else
				false
			end	
		end

		def is_embed_library(name)
			if @embed_binaries.include?(name)
				true
			else
				false
			end
		end

		def phase_include?(name, phase)
			ref_included = phase.file_display_names
			for ref_name in ref_included do
				if ref_name.eql?(name)
					return true
				end
			end
			false
		end

		def merge_hash(hash, other_hash)
			other_hash.keys.each do |key|
				if hash.key?(key)
					value = hash[key]
					if value.class.name.eql?('Hash')
						if other_hash[key].class.name.eql?('Hash')
							merge_hash(hash[key], other_hash[key])
						else
							puts "invilid format. merge can not finished!"
						end
					elsif value.class.name.eql?('Array')
						if other_hash[key].class.name.eql?('Array')
							hash[key] = value | other_hash[key]
						else
							puts "invilid format. merge can not finished!"
						end
					else
						hash[key] = other_hash[key]
					end
				else
					hash[key] = other_hash[key]
				end
			end
		end

		def dealwith_other_linker_flags(linker_flags)
			exists_linker_flags = @target.build_configuration_list.get_setting('OTHER_LDFLAGS')['Release']
			flags = linker_flags
			if exists_linker_flags.class.name.eql?('Array')
				flags = linker_flags | exists_linker_flags
			elsif exists_linker_flags.class.name.eql?('String')
				flags = linker_flags << exists_linker_flags
			end
			flags_to_string = flags[0]
			flags.each do |item|
				unless item.eql?(flags[0])
					flags_to_string << " #{item}"
				end
			end
			flags_to_string
		end


		def dealwith_run_search_path(paths)
			exists_paths = @target.build_configuration_list.get_setting('LD_RUNPATH_SEARCH_PATHS')['Release']
			if exists_paths.class.name.eql?('Array')
				paths = paths | exists_paths
			elsif exists_paths.class.name.eql?('String')
				paths = paths << exists_paths
			end
			paths_to_string = paths[0]
			paths.each do |item|
				unless item.eql?(paths[0])
					paths_to_string << " #{item}"
				end
			end
			paths_to_string
		end

		def get_copy_files_build_phase_for_framework
			copy_files_build_phase = nil
			for phase in @target.build_phases 
				if phase.class.name.eql?('Xcodeproj::Project::Object::PBXCopyFilesBuildPhase')
					if phase.dst_subfolder_spec.eql?('10')
						copy_files_build_phase = phase
						break
					end
				end
			end
			unless copy_files_build_phase
				copy_files_build_phase = @target.new_copy_files_build_phase
				copy_files_build_phase.symbol_dst_subfolder_spec=(:frameworks)		
				copy_files_build_phase.name = 'Embed Frameworks'
			end	
			@copy_files_build_phase = copy_files_build_phase
		end

		def get_name_from_path(path)
			if path.include?('/')
				path.split('/').last
			else
				path
			end
		end

		def add_binary_search_path(path)
			new_path = Pathname.new(path)
			file_path = new_path.parent
			file_name = new_path.basename.to_s
			project_root_path = Pathname.new(@project.path.parent)
			framework_releative_path = "$(SRCROOT)/" << file_path.relative_path_from(project_root_path).to_s

			build_configurations = @target.build_configuration_list
			search_path_name = nil
			if file_name.end_with?('.framework')
				search_path_name = 'FRAMEWORK_SEARCH_PATHS'
			else
				search_path_name = 'LIBRARY_SEARCH_PATHS'
			end
			search_paths = build_configurations.get_setting(search_path_name)['Release']
			if !search_paths
				search_paths = Array[framework_releative_path]
				build_configurations.set_setting(search_path_name, search_paths);
			elsif !search_paths.include?(framework_releative_path)
				puts "add #{search_path_name}: #{path}"
				search_paths << framework_releative_path
				build_configurations.set_setting(search_path_name, search_paths);
			end
		end

		def  add_dir_reference(path, group)
			Dir.entries(path).each do |child|
				child_path = "#{path}/#{child}"
				if is_excludes(child)
					puts "ignore entry: #{child_path}"
				elsif File.directory?(child_path) && !(child.end_with?(".framework", ".bundle"))
					child_group = group.find_subpath(File.join(child), true)
					add_dir_reference(child_path, child_group)
				else
					if is_resource(child) && !phase_include?(child, @target.resources_build_phase)
						puts "add resource: #{child_path}" 
						resource_ref = group.new_reference(child_path)
						@target.resources_build_phase.add_file_reference(resource_ref)
					elsif is_binary_library(child) && is_embed_library(child)
						puts "add embed framework: #{child_path}"
						if !@copy_files_build_phase
							get_copy_files_build_phase_for_framework
						end
						if !phase_include?(child, @copy_files_build_phase)
							framework_ref = group.new_reference(child_path)
							@copy_files_build_phase.add_file_reference(framework_ref)
							add_binary_search_path(child_path)
							build_file = framework_ref.build_files.at(0)
							build_file.settings = Hash[
								'ATTRIBUTES' => Array["CodeSignOnCopy"]
							]
							build_configurations = @target.build_configuration_list
							paths = Array["$(inherited)", "@executable_path/Frameworks"]
							build_configurations.set_setting('LD_RUNPATH_SEARCH_PATHS', dealwith_run_search_path(paths))
						end
					elsif is_binary_library(child) && !is_embed_library(child) && !phase_include?(child, @target.frameworks_build_phase)
						puts "add static framework: #{child_path}"
						framework_ref = group.new_reference(child_path)
						@target.frameworks_build_phase.add_file_reference(framework_ref)
						add_binary_search_path(child_path)
					elsif is_head_file(child) && !phase_include?(child, @target.headers_build_phase)
						puts "add headfile: #{child_path}"
						head_file_ref = group.new_reference(child_path)
						@target.headers_build_phase.add_file_reference(head_file_ref)
					elsif is_source_file(child) && !phase_include?(child, @target.source_build_phase)
						puts "add sourcefile: #{child_path}"
						source_file_ref = group.new_reference(child_path)
						@target.source_build_phase.add_file_reference(source_file_ref)
					end
				end
			end
		end

		def  processs_sys_framework
			puts "\nprocesss_sys_framework..."
			puts "--------------------------------------------------"
			if @xcmod['sys_frameworks'].empty?
				puts "Nothing to do."
			end
			@xcmod['sys_frameworks'].each do |framework|
				unless phase_include?("#{framework}.framework", @target.frameworks_build_phase)
					puts "add system framework: #{framework}.framework"
					@target.add_system_frameworks([framework])
				end
			end
		end

		def  processs_sys_lib
			puts "\nprocesss_sys_lib..."
			puts "--------------------------------------------------"
			if @xcmod['sys_libs'].empty?
				puts "Nothing to do."
			end
			@xcmod['sys_libs'].each do |lib|
				unless phase_include?("#{lib}.dylib", @target.frameworks_build_phase)
					puts "add system dylib: #{lib}.dylib"
					# xcodeproj use 'lib#{lib}.dylib' format, so delete 'lib' substring from lib at start index.
					lib[0..2] = ""
					@target.add_system_libraries([lib])
				end
			end
		end

		def  process_folders
			puts "\nprocess_folders..."
			puts "--------------------------------------------------"
			if @xcmod['folders'].empty?
				puts "Nothing to do."
			end
			@xcmod['folders'].each do |folder|
				folder_path = "#{Dir.pwd}/#{folder}"
				if @modify_with_copy
					dist_path = "#{@project.path}/../#{@release_dir_name}"
					if !File.exist?(dist_path)
						system("mkdir -p " << dist_path)
					end
					puts "cp #{folder_path} to #{dist_path}..."
					system("cp -r " << folder_path << " " << dist_path)
					folder_path = "#{dist_path}/#{get_name_from_path(folder_path)}"
				end
				
				sub_group = get_name_from_path(folder_path)
				group = @project.main_group.find_subpath(File.join(sub_group), true)
				group.set_source_tree('SOURCE_ROOT')
				add_dir_reference(folder_path, group)
			end
		end

		def process_embed_binaries
			puts "\nprocess_embed_binaries..."
			puts "--------------------------------------------------"
			if @xcmod['embed_binaries'].empty?
				puts "Nothing to do."
			end
			@xcmod['embed_binaries'].each do |binary|
				puts "add embed binary: #{binary}"
				@embed_binaries << binary
			end
		end

		def  process_plist
			puts "\nprocess_plist..."
			puts "--------------------------------------------------"
			if @xcmod['plist'].empty?
				puts "Nothing to do."
			end
			project_path = @project.path
			relative_plist_path = @target.build_configuration_list.build_settings('Release')['INFOPLIST_FILE']
			plist_path = "#{project_path}/../#{relative_plist_path}"
			puts "plist path: #{plist_path}"
			hash = Xcodeproj::Plist::read_from_path(plist_path)
			plist = @xcmod['plist']
			puts "add plist content: #{plist}"
			if plist['urltypes']
				format_types = Array.new
				plist['urltypes'].each do |type|
					format_type = Hash.new
					format_type['CFBundleTypeRole'] = type['role']
					format_type['CFBundleURLName'] = type['identifier']
					format_type['CFBundleURLSchemes'] = type['schemes']
					format_types << format_type
				end
				if hash['CFBundleURLTypes']
					format_types.each do |type|
						hash['CFBundleURLTypes'] << type
					end
				else
					hash['CFBundleURLTypes'] = format_types
				end
				hash['CFBundleURLTypes'].uniq!
				plist.delete('urltypes')
			end
			if plist['CFBundleIdentifier']
				build_configurations = @target.build_configuration_list
				build_configurations.set_setting('PRODUCT_BUNDLE_IDENTIFIER', plist['CFBundleIdentifier'])
			end
			#hash.merge!(plist)
			merge_hash(hash, plist)
			if @modify_with_copy
				dist_plist_path = "#{@project.path}/../#{@release_dir_name}/Info.plist"
				puts "save plist at #{dist_plist_path}"
				Xcodeproj::Plist::write_to_path(hash, dist_plist_path)
				plist_ref = @project.main_group.new_reference(dist_plist_path)
				build_configurations = @target.build_configuration_list
				build_configurations.set_setting('INFOPLIST_FILE', dist_plist_path)
			else
				Xcodeproj::Plist::write_to_path(hash, plist_path)
			end
		end

		def process_build_settings
			puts "\nprocess_build_settings..."
			puts "--------------------------------------------------"
			if @xcmod['build_settings'].empty?
				puts "Nothing to do."
			end
			build_setings_hash = Hash[
				'OTHER_LINKER_FLAGS' => 'OTHER_LDFLAGS'
			]
			build_configurations = @target.build_configuration_list
			build_setings = @xcmod['build_settings']
			build_setings.keys.each do |key|
				if key.eql?('other_linker_flags')
					build_setings[key] = dealwith_other_linker_flags(build_setings[key])
				end
				puts "set #{key} => #{build_setings[key]}"
				if build_setings_hash.key?(key)
					build_configurations.set_setting(build_setings_hash[key], build_setings[key])
				else
					build_configurations.set_setting(key, build_setings[key])
				end
			end
		end

		def process_resource_replace
			puts "\nprocess_resource_replace..."
			puts "--------------------------------------------------"
			if @xcmod['resource_replace'].empty?
				puts "Nothing to do."
			end
			resources_cover = @xcmod['resource_replace']
			resoures_ref = @target.resources_build_phase.files_references
			
			resources_cover.each do |item|
				item_name = get_name_from_path(item)
				for ref in resoures_ref do
					ref_name = ref.real_path.basename.to_s
					if ref_name.eql?(item_name)
						puts "replace resource: #{item_name}"
						@target.resources_build_phase.remove_file_reference(ref)
						ref.remove_from_project
						item_path = "#{Dir.pwd}/#{item}"

						if @modify_with_copy
							dist_path = "#{@project.path}/../#{@release_dir_name}"
							if !File.exist?(dist_path)
								system("mkdir -p " << dist_path)
							end
							puts "cp #{item_path} to #{dist_path}..."
							system("cp -r " << item_path << " " << dist_path)
							item_path = "#{dist_path}/#{get_name_from_path(item_path)}"
						end

						item_ref = @project.main_group.new_reference(item_path)
						@target.resources_build_phase.add_file_reference(item_ref)
						break
					end
				end
			end
		end

		def process_file_remove
			puts "\nprocess_file_remove..."
			puts "--------------------------------------------------"
			if @xcmod['file_remove'].empty?
				puts "Nothing to do."
			end
			files_remove = @xcmod['file_remove']
			files_remove.each do |file|
				if is_resource(file)
					files_ref = @target.resources_build_phase.files_references
					for file_ref in files_ref do
						ref_name = file_ref.real_path.basename.to_s
						if ref_name.eql?(file)
							puts "remove resource: #{file_ref.real_path.to_s}"
							@target.resources_build_phase.remove_file_reference(file_ref)
							file_ref.remove_from_project
							break
						end
					end
				elsif is_binary_library(file) && !is_embed_library(file)
					files_ref = @target.frameworks_build_phase.files_references
					for file_ref in files_ref do
						ref_name = file_ref.real_path.basename.to_s
						if ref_name.eql?(file)
							puts "remove resource: #{file_ref.real_path.to_s}"
							@target.frameworks_build_phase.remove_file_reference(file_ref)
							file_ref.remove_from_project
							break
						end
					end
				# embed_binary, head_file, source_file not implement
				end
			end
		end

		def process_codesign
			puts "\nprocess_codesign..."
			puts "--------------------------------------------------"
			if @xcmod['code_sign'].empty?
				puts "Nothing to do."
			end
			# confirm codesign type [Automatic, Manual] and close push, gamecenter, iap capabilities
			atts = @project.root_object.attributes['TargetAttributes']
			atts.each do |att|
				if att.last.key?('ProvisioningStyle')
					puts "set ProvisioningStyle => Manual"
					att.last['ProvisioningStyle'] = "Manual"
					if att.last.key?('DevelopmentTeam')
						att.last.delete('DevelopmentTeam')
					end
					puts "close push, gamecenter, iap capabilities..."
					close_hash = Hash.new
					close_hash = {'SystemCapabilities' => {
						'com.apple.GameCenter' => {'enabled' => '0'},
						'com.apple.InAppPurchase' => {'enabled' => '0'},
						'com.apple.Push' => {'enabled' => '0'}
						}
					}
					merge_hash(att.last, close_hash)
				end
			end
			# process codesign
			puts "set codesign => #{@xcmod['code_sign']}"
			build_configurations = @target.build_configuration_list
			codesign = @xcmod['code_sign']
			build_configurations.set_setting('CODE_SIGN_IDENTITY', codesign['CODE_SIGN_IDENTITY'])
			build_configurations.set_setting('CODE_SIGN_IDENTITY[sdk=iphoneos*]', codesign['CODE_SIGN_IDENTITY'])
			build_configurations.set_setting('DEVELOPMENT_TEAM', codesign['DEVELOPMENT_TEAM'])
			build_configurations.set_setting('PROVISIONING_PROFILE', codesign['PROVISIONING_PROFILE'])
			build_configurations.set_setting('PROVISIONING_PROFILE_SPECIFIER', codesign['PROVISIONING_PROFILE'])
		end

		def build_ipa(project_path, target_name = "", configuration = "Release", clean_before_build = true)
			m_project = Xcodeproj::Project.open(project_path)
			m_target = nil
			if target_name.empty?
				m_target = m_project.targets.first
			else
				for target in m_project.targets do
					if target.name.eql?(target_name)
						m_target = target
						break;
					end
				end
			end

			cmd = "xcodebuild -project #{project_path} -target #{m_target.name} -configuration #{configuration} build"
			if clean_before_build
				cmd = "xcodebuild -project #{project_path} -target #{m_target.name} -configuration #{configuration} clean build"
			end
			system "#{cmd}"
			cur_path = Dir.pwd
			Dir.chdir "#{project_path}/../"
			release_path = './Payload'
			if File.exists?(release_path)
				system "rm -r #{release_path}"
			end
			system "mkdir -p #{release_path}"
			system "cp -r " << "./build/#{configuration}-iphoneos/#{m_target.product_name}.app" << " #{release_path}"
			system "zip -r -q #{m_target.product_name}.ipa Payload"
			system "rm -r #{release_path}"
			puts "********************* BUILD IPA SUCCCESS! *********************"
			puts "ipa at: #{Dir.pwd}/#{m_target.product_name}.ipa"
			Dir.chdir cur_path
		end

		def self.build_ipa(project_path, target_name = "", configuration = "Release", clean_before_build = true)
			m_project = XCProject.new(project_path, nil)
			m_project.build_ipa(project_path, target_name, configuration, clean_before_build)
		end

		def apply_modify(project_path_new = nil)
			puts "\n****************** MODIFY BEGIN ******************"
			#prepare
			if project_path_new
				@modify_with_copy = true
			end
			if @xcmod['release_dir']
				@release_dir_name = @xcmod['release_dir']
			end

			#process
			if @xcmod['sys_frameworks']
				processs_sys_framework()
			end
			if @xcmod['sys_libs']
				processs_sys_lib()
			end
			if @xcmod['embed_binaries']
				process_embed_binaries()
			end
			if @xcmod['folders']
				process_folders()
			end
			if @xcmod['plist']
				process_plist()
			end
			if @xcmod['build_settings']
				process_build_settings()
			end
			if @xcmod['resource_replace']
				process_resource_replace()
			end
			if @xcmod['file_remove']
				process_file_remove()
			end
			if @xcmod['code_sign']
				process_codesign()
			end

			#save project
			if project_path_new
				@project.save(project_path_new)
			else
				@project.save
			end
			puts "\n******************* MODIFY END *******************"
		end
	end
end




