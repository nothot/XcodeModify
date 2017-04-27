
XcodeModify 是一个使用脚本来自动化配置xcode工程的工具

XcodeModify是ruby脚本，需要ruby环境，并安装xcodeproj，关于xcodeproj可以参考https://github.com/CocoaPods/Xcodeproj

如何使用XcodeModify？

你仅仅需要编辑一个配置文件，配置文件需命名为xcmod.json，XcodeModify会读取配置文件，并按照配置文件中的指令执行脚本，实现自动化调整xcode工程

使用示例：

project_path = '***/***.xcodeproj'

xcproject = XcodeModify::XCProject.new(project_path, 'xcmod.json')

project_path_new = '***/***.xcodeproj'

xcproject.apply_modify(project_path_new)

apply_modify不指定参数时表示修改原工程，指定新的工程路径则生成新的调整后的工程

下面给出xcmod.json支持的指令：

comment：注释

release_dir：所有增加到工程中的文件都会统一放在此目录

sys_frameworks：向工程增加系统framework的引用

sys_libs：向工程增加系统dylib库引用

folders：向工程增加某个目录的引用

embed_binaries：向工程增加第三方动态库的引用

plist：修改工程plist文件

build_settings：修改工程build setting

resource_replace：替换工程中的某些资源文件

file_remove：移除工程中的某些文件引用

code_sign：修改工程签名



