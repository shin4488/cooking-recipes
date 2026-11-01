#!/bin/sh
# アプリと同じ文面から、公開する Web ページを web/public に作る。運営者名と問い合わせ先は Config/Local.xcconfig から入れる
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
xcrun swiftc -o "$work/generate" RecipePocket/Support/PolicyText.swift web/generator/main.swift
"$work/generate" Config/Local.xcconfig web/public
