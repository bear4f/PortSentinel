#!/usr/bin/env bash
set -Eeuo pipefail
printf '*filter\n:INPUT ACCEPT [0:0]\nCOMMIT\n'
