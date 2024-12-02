# 获取当前目录
import os
import sys
current_dir = os.path.dirname(os.path.abspath(__file__))
print(current_dir)
project_dir = os.path.abspath(os.path.join(current_dir, '..', '..'))
print(project_dir)
include_dir = os.path.join(project_dir, 'include')
src_dir = os.path.join(project_dir, 'src')

# 提示输入模块名
module_name = input("请输入模块名: ")

module_inc_dir = os.path.join(include_dir, module_name)
module_src_dir = os.path.join(src_dir, module_name)
# 如果module_inc_dir和module_src_dir目录已经存在，则提示用户输入新的模块名
while os.path.exists(module_inc_dir) or os.path.exists(module_src_dir):
    print("模块名已存在，请重新输入: ")
    module_name = input("请输入模块名: ")
    module_inc_dir = os.path.join(project_dir, module_name)
    module_src_dir = os.path.join(src_dir, module_name)

# 创建模块目录
os.makedirs(module_inc_dir)
os.makedirs(module_src_dir)

module_cmake_file = os.path.join(module_src_dir, 'CMakeLists.txt')

file_content = f"""
bxk_add_module({module_name} 0.1.0)
file(GLOB TARGET_SOURCES
  "*.hpp"
  "*.cpp"
  "*.cc"
)
target_sources(
  {module_name}
    PRIVATE
    ${{TARGET_SOURCES}}
)
bxk_install_module({module_name})
"""

with open(module_cmake_file, 'w') as f:
    f.write(file_content)



src_root_cmake_file = os.path.join(src_dir, 'CMakeLists.txt')
# 如果src_root_cmake_file文件不存在，则创建一个空的文件
if not os.path.exists(src_root_cmake_file):
    with open(src_root_cmake_file, 'w') as f:
        pass
    print("创建空文件: ", src_root_cmake_file)

# 打开并读取 src_root_cmake_file 文件内容
with open(src_root_cmake_file, 'r') as f:
    file_content = f.read()

file_content = file_content.replace('# subdir-loc', f"add_subdirectory({module_name})\n# subdir-loc")
# 将src_root_cmake_file文件内容中的subdir-loc字符串替换为ABABA
with open(src_root_cmake_file, 'w') as f:
    f.write(file_content)



