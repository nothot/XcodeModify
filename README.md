## 介绍

XcodeModify 是一个使用脚本来自动化配置xcode工程的工具

XcodeModify是ruby脚本，需要ruby环境，并安装xcodeproj，关于xcodeproj可以参考https://github.com/CocoaPods/Xcodeproj

如何使用XcodeModify？

你仅仅需要编辑一个配置文件，配置文件需命名为xcmod.json，XcodeModify会读取配置文件，并按照配置文件中的指令执行脚本，实现自动化调整xcode工程

## 使用示例

```ruby
project_path = '***/***.xcodeproj'
xcproject = XcodeModify::XCProject.new(project_path, 'xcmod.json')
project_path_new = '***/***.xcodeproj'
xcproject.apply_modify(project_path_new)
```
apply_modify不指定参数时表示修改原工程，指定新的工程路径则生成新的调整后的工程

## 命名介绍

下面给出xcmod.json支持的命令：

comment：注释

release_dir：所有增加到工程中的文件都会统一放在此目录，你可以任意命名该目录的名字

sys_frameworks：向工程增加系统framework的引用，该项对应一个数组，可以包含任意多个需要添加到工程的系统framework，注意framework名不需带后缀

sys_libs：向工程增加系统dylib库引用，同上，也是一个数组

folders：向工程增加某个目录的引用。你可以指定任意一个目录，将其依赖到工程中，目录下的所有类型的文件（包含各种资源文件，源代码文件，静态库，动态库等）都会按照类型正确的引用到工程中，该处理会递归查找所有文件，因此

目录下也可以包含二级目录，三级目录等。该项对应的是一个数组，因此你可以指定多个目录，将其添加到工程中。

embed_binaries：向工程增加第三方动态库的引用。事实上，任何需要添加到工程中的文件都应该通过folders命令来做，该命令只是标记通过folders添加的某个文件是动态库，应该按照动态库的方式处理。该项为数组，你可以指定多个

文件为动态库，folders在处理的时候会根据这里的标记，对动态库文件进行正确的处理

plist：修改工程plist文件，可以参考sample中示例，按照key-value的形式修改

build_settings：修改工程build setting，可以参考sample中示例，按照key-value的形式修改

resource_replace：替换工程中的某些资源文件，该项为数组，可指定任意多个资源文件，该操作会替换所有工程中同名的资源文件

file_remove：移除工程中的某些文件引用，该项为数组，可指定任意多个文件，该操作会从工程中移除所有数组中指定的文件

code_sign：修改工程签名，可以参考sample中示例



