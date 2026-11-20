#!/bin/bash
# 岁月回声 HarmonyOS · 命令行构建脚本
# 用法：./build.sh            → debug HAP
#       ./build.sh release    → release HAP
# 依赖：本机已安装 DevEco Studio 26.0.0（/Applications/DevEco-Studio.app）
set -euo pipefail

APP="/Applications/DevEco-Studio.app"
export DEVECO_SDK_HOME="$APP/Contents/sdk"
export JAVA_HOME="$APP/Contents/jbr/Contents/Home"
export PATH="$APP/Contents/tools/node/bin:$APP/Contents/tools/ohpm/bin:$JAVA_HOME/bin:$PATH"

MODE="${1:-debug}"
cd "$(dirname "$0")"

echo "== ohpm install =="
ohpm install --all

echo "== hvigor assembleHap ($MODE) =="
if [ "$MODE" = "release" ]; then
  "$APP/Contents/tools/hvigor/bin/hvigorw" assembleHap --mode module -p product=default -p buildMode=release --no-daemon
else
  "$APP/Contents/tools/hvigor/bin/hvigorw" assembleHap --mode module -p product=default --no-daemon
fi

echo "== 产物 =="
ls -lh entry/build/default/outputs/default/*.hap
