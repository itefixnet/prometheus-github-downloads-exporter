#!/bin/bash
#
# GitHub Downloads Prometheus Exporter Configuration
# Source this file to configure the exporter settings
#

# GitHub API Configuration
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"
export GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
export GITHUB_ACCOUNT="${GITHUB_ACCOUNT:-}"
export GITHUB_REPO="${GITHUB_REPO:-}"

# Filtering Configuration
export REPO_REGEX="${REPO_REGEX:-.*}"
export RELEASE_REGEX="${RELEASE_REGEX:-.*}"
export ASSET_REGEX="${ASSET_REGEX:-.*}"

# Release Grouping Configuration
# Format: "group1:regex1,group2:regex2,group3:regex3"
export RELEASE_GROUP_PATTERNS="${RELEASE_GROUP_PATTERNS:-}"

# Prometheus Exporter Configuration
export METRICS_PREFIX="${METRICS_PREFIX:-github_downloads}"

# HTTP Server Configuration
export LISTEN_PORT="${LISTEN_PORT:-9168}"
export LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0}"
export MAX_CONNECTIONS="${MAX_CONNECTIONS:-10}"
export TIMEOUT="${TIMEOUT:-60}"

# Logging Configuration
export LOG_LEVEL="${LOG_LEVEL:-info}"

# Performance Configuration
export CACHE_TTL="${CACHE_TTL:-300}"  # seconds to cache API responses
export RATE_LIMIT_DELAY="${RATE_LIMIT_DELAY:-1}"  # seconds between API calls

# Cache Configuration
export CACHE_DIR="${CACHE_DIR:-/tmp/github-downloads-exporter}"

# Advanced Configuration
export ENABLE_ASSET_METRICS="${ENABLE_ASSET_METRICS:-true}"
export ENABLE_RELEASE_METRICS="${ENABLE_RELEASE_METRICS:-true}"
export ENABLE_REPOSITORY_METRICS="${ENABLE_REPOSITORY_METRICS:-true}"
export ENABLE_RATE_LIMIT_METRICS="${ENABLE_RATE_LIMIT_METRICS:-true}"

# Example configurations for common use cases:

# Monitor specific repository:
# export GITHUB_ACCOUNT="octocat"
# export GITHUB_REPO="Hello-World"

# Monitor all repositories for an account:
# export GITHUB_ACCOUNT="octocat"

# Monitor repositories matching a pattern:
# export GITHUB_ACCOUNT="kubernetes"
# export REPO_REGEX=".*client.*"

# Monitor only stable releases (no pre-releases or RCs):
# export RELEASE_REGEX="^v?[0-9]+\.[0-9]+\.[0-9]+$"

# Monitor only specific asset types:
# export ASSET_REGEX="\.(tar\.gz|zip|deb|rpm)$"

# Group releases by type (stable, beta, rc, other):
# export RELEASE_GROUP_PATTERNS="stable:^v?[0-9]+\.[0-9]+\.[0-9]+$,beta:.*-beta.*,rc:.*-rc.*"

# Group releases by major version:
# export RELEASE_GROUP_PATTERNS="v1:^v?1\.,v2:^v?2\.,v3:^v?3\."

# Group releases by pre-release status:
# export RELEASE_GROUP_PATTERNS="stable:^v?[0-9]+\.[0-9]+\.[0-9]+$,prerelease:.*"

# GitHub Enterprise configuration:
# export GITHUB_API_URL="https://github.company.com/api/v3"