#!/usr/bin/ruby


# xcodemodify使用示例脚本

$LOAD_PATH << '.'
require 'xcodemodify'

# 设置需要调整的工程路径
project_path = './test/test.xcodeproj'
# 设置配置的json文件路径
mod_path = './xcmod.json'
xcproject = XcodeModify::XCProject.new(project_path, mod_path)
# 设置新的调整后的工程路径
project_path_new = './test/test2.xcodeproj'
# 传入路径并执行脚本，如若不传则修改原工程
xcproject.apply_modify(project_path_new)