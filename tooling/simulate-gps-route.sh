#!/usr/bin/env bash
set -euo pipefail

tooling_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
route_file="${tooling_dir}/fixtures/park-loop.waypoints"
device="${SIMULATOR_UDID:-booted}"
speed="${SPEED:-6}"
interval="${INTERVAL:-1}"
action="${1:-start}"

if [[ "${action}" == "clear" ]]; then
  xcrun simctl location "${device}" clear
  echo "已清除 ${device} 的模拟定位"
  exit 0
fi

if [[ "${action}" == "prepare" ]]; then
  first_point="$(sed -n '1p' "${route_file}")"
  xcrun simctl location "${device}" set "${first_point}"
  echo "已将 ${device} 定位到轨迹起点 ${first_point}"
  echo "现在在 Movea 中点击开始运动，再执行："
  echo "  ${BASH_SOURCE[0]} start"
  exit 0
fi

if [[ "${action}" != "start" ]]; then
  echo "用法：${BASH_SOURCE[0]} [prepare|start|clear]" >&2
  exit 2
fi

if [[ ! -f "${route_file}" ]]; then
  echo "找不到轨迹文件：${route_file}" >&2
  exit 1
fi

echo "开始回放 ${route_file}"
echo "设备=${device} 速度=${speed}m/s 间隔=${interval}s"
echo "这是通过 iOS Simulator 注入 Core Location 的位置，不会向 App 注入路线或运动统计。"
xcrun simctl location "${device}" start \
  "--speed=${speed}" \
  "--interval=${interval}" \
  - < "${route_file}"
echo "轨迹回放完成"
