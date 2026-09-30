#!/bin/sh
# 사용법: ./check.sh [경로]   (기본: mock-data.json)
BASE=https://haechisooplive-jpg.github.io/mock-assets
curl -sI "$BASE/${1:-mock-data.json}" | grep -iE '^(HTTP|content-type|access-control-allow-origin|content-length)'
