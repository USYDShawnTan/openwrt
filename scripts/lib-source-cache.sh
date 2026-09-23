#!/usr/bin/env bash
# shellcheck shell=bash
# GitHub source archive cache.  No git clone/mirror is used.

SOURCE_CACHE_DIR="${SOURCE_CACHE_DIR:-$HOME/openwrt-build/source-cache}"
GITHUB_PROXY_PREFIX="${GITHUB_PROXY_PREFIX:-}"
mkdir -p "$SOURCE_CACHE_DIR"

_sanitize_ref() {
  printf '%s' "$1" | tr '/:@ ' '____'
}

_source_archive_url() {
  local repo="$1" ref="$2"
  printf 'https://codeload.github.com/%s/tar.gz/%s' "$repo" "$ref"
}

ensure_source_archive() {
  local repo="$1" name="$2" ref="$3"
  local safe_ref archive tmp url
  safe_ref="$(_sanitize_ref "$ref")"
  archive="$SOURCE_CACHE_DIR/${name}-${safe_ref}.tar.gz"
  tmp="${archive}.part"
  url="$(_source_archive_url "$repo" "$ref")"
  [[ -n "$GITHUB_PROXY_PREFIX" ]] && url="${GITHUB_PROXY_PREFIX}${url}"

  if [[ -f "$archive" ]] && tar -tzf "$archive" >/dev/null 2>&1; then
    echo "==> source cache hit:  $name @ $ref" >&2
    printf '%s\n' "$archive"
    return 0
  fi

  rm -f "$archive"
  echo "==> source cache miss: $name @ $ref" >&2
  echo "    $url" >&2

  # A failed download is kept as .part and resumed on the next attempt when possible.
  if [[ -s "$tmp" ]]; then
    if ! curl -fL --retry 6 --retry-delay 3 --retry-all-errors \
      --connect-timeout 20 --speed-time 30 --speed-limit 1024 \
      -C - "$url" -o "$tmp"; then
      echo "==> resume failed, retrying from zero: $name" >&2
      rm -f "$tmp"
    fi
  fi

  if [[ ! -s "$tmp" ]]; then
    curl -fL --retry 6 --retry-delay 3 --retry-all-errors \
      --connect-timeout 20 --speed-time 30 --speed-limit 1024 \
      "$url" -o "$tmp"
  fi

  if ! tar -tzf "$tmp" >/dev/null 2>&1; then
    echo "ERROR: downloaded archive is invalid: $tmp" >&2
    rm -f "$tmp"
    return 1
  fi

  mv "$tmp" "$archive"
  printf '%s\n' "$archive"
}

export_source_tree() {
  local repo="$1" name="$2" ref="$3" dest="$4"
  local archive
  archive="$(ensure_source_archive "$repo" "$name" "$ref")"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xzf "$archive" -C "$dest" --strip-components=1
}

export_source_subdir() {
  local repo="$1" name="$2" ref="$3" subdir="$4" dest="$5"
  local archive tmp
  archive="$(ensure_source_archive "$repo" "$name" "$ref")"
  tmp="$(mktemp -d)"
  tar -xzf "$archive" -C "$tmp" --strip-components=1
  if [[ ! -e "$tmp/$subdir" ]]; then
    echo "ERROR: source subdir not found: $name @ $ref -> $subdir" >&2
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -a "$tmp/$subdir" "$dest"
  rm -rf "$tmp"
}
