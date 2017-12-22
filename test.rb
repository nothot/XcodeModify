#!/usr/bin/ruby


# xcodemodify使用示例脚本
# 终端下切到脚本所在目录，执行 'ruby test.rb'即可（请先确保安装了xcodeproj组件）

$LOAD_PATH << '.'
require 'xcodemodify'

project_path = './test/test.xcodeproj'
mod_path = './xcmod.json'
xcproject = XcodeModify::XCProject.new(project_path, mod_path)
project_path_new = './test/test2.xcodeproj'
xcproject.apply_modify(project_path_new)