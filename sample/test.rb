#!/usr/bin/ruby

# cd sample directory. run 'ruby test.rb' to see how xcodemodify works

$LOAD_PATH << '../'
require 'xcodemodify'

project_path = 'xcmodTest/xcmodTest.xcodeproj'
xcproject = XcodeModify::XCProject.new(project_path, 'xcmod.json')
project_path_new = 'xcmodTest/xcmodTest2.xcodeproj'
xcproject.apply_modify(project_path_new)
#xcproject.build_ipa(project_path_new)