#!/bin/sh
# clone したあとに1回だけ実行する git の設定（docs/setup.md）。
# 1. Xcode が project.pbxproj に書き戻す個人の Team ID（DEVELOPMENT_TEAM）を、ステージ時に自動で取り除く filter
# 2. それでも混ざっていたらコミットを止める pre-commit hook
# どちらも git の設定は clone ごとに持つもので、リポジトリには入らない。

set -e
cd "$(git rev-parse --show-toplevel)"

git config filter.xcodeteam.clean "sed -e '/DEVELOPMENT_TEAM = /d'"
git config filter.xcodeteam.smudge cat
git config core.hooksPath .githooks

echo "設定しました："
echo "  filter.xcodeteam.clean = $(git config filter.xcodeteam.clean)"
echo "  core.hooksPath         = $(git config core.hooksPath)"
