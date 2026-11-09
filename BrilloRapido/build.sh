#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
app_path="${1:-${project_dir}/BrilloRapido.app}"
build_dir="${project_dir}/.build"
module_cache="${build_dir}/ModuleCache"

mkdir -p "${build_dir}" "${module_cache}"
mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Helpers" "${app_path}/Contents/Resources"

swiftc -swift-version 5 -O -module-cache-path "${module_cache}" \
  -framework AppKit -framework SwiftUI -framework CoreGraphics \
  "${project_dir}"/Sources/*.swift \
  -o "${app_path}/Contents/MacOS/BrilloRapido"

clang -O2 -Wall -Wextra -fmodules -fmodules-cache-path="${module_cache}" \
  -I "${project_dir}/ThirdParty/m1ddc/headers" \
  "${project_dir}/ThirdParty/m1ddc/sources/i2c.m" \
  "${project_dir}/ThirdParty/m1ddc/sources/ioregistry.m" \
  "${project_dir}/ThirdParty/m1ddc/sources/m1ddc.m" \
  -framework CoreDisplay \
  -o "${app_path}/Contents/Helpers/m1ddc"

cp "${project_dir}/Info.plist" "${app_path}/Contents/Info.plist"
cp "${project_dir}/ThirdParty/m1ddc/LICENSE" "${app_path}/Contents/Resources/m1ddc-LICENSE.txt"
cp "${project_dir}/Resources/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"

codesign --force --sign - "${app_path}/Contents/Helpers/m1ddc"
codesign --force --sign - "${app_path}"
echo "Created ${app_path}"
