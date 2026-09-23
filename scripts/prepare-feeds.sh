#!/usr/bin/env bash
set -euo pipefail
OPENWRT_DIR="${1:?usage: prepare-feeds.sh <openwrt-dir>}"
cd "$OPENWRT_DIR"

# v4.5 不再覆盖官方 feeds 版本，完全使用当前 OpenWrt Release 自带 feeds.conf.default。
cp feeds.conf.default feeds.conf

# feeds.conf.default 使用 ^commit 固定官方 feed。若本地 checkout 已经是目标 commit，
# 就不访问网络；只有缺失或版本变化时才 update。
while read -r kind name url; do
  [[ "$kind" == src-git* ]] || continue
  ref=""
  if [[ "$url" == *'^'* ]]; then
    ref="${url##*^}"
  fi

  if [[ -n "$ref" && -d "feeds/$name/.git" ]]; then
    current="$(git -C "feeds/$name" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$current" == "$ref" ]]; then
      git -C "feeds/$name" reset -q --hard "$ref"
      git -C "feeds/$name" clean -q -fd
      echo "==> feed cache hit: $name @ ${ref:0:12}"
      continue
    fi
  fi

  echo "==> updating feed: $name"
  ./scripts/feeds update "$name"
done < feeds.conf

./scripts/feeds install -a
