# Example configurations for GitHub Downloads Exporter

# Example 1: Monitor specific repository
export GITHUB_ACCOUNT="prometheus"
export GITHUB_REPO="prometheus"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 2: Monitor all repositories for an organization
export GITHUB_ACCOUNT="kubernetes"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 3: Monitor repositories matching a pattern
export GITHUB_ACCOUNT="kubernetes"
export REPO_REGEX=".*client.*"  # Only monitor client libraries
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 4: Monitor only stable releases (no pre-releases or release candidates)
export GITHUB_ACCOUNT="prometheus"
export RELEASE_REGEX="^v?[0-9]+\.[0-9]+\.[0-9]+$"  # Only x.y.z versions
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 5: Monitor only binary assets (exclude source code)
export GITHUB_ACCOUNT="prometheus"
export ASSET_REGEX="\.(tar\.gz|zip|deb|rpm|exe|msi)$"  # Only binary packages
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 6: GitHub Enterprise configuration
export GITHUB_API_URL="https://github.company.com/api/v3"
export GITHUB_ACCOUNT="internal-team"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 7: High-frequency monitoring with caching
export GITHUB_ACCOUNT="popular-org"
export CACHE_TTL=600  # 10 minutes cache
export RATE_LIMIT_DELAY=2  # 2 seconds between API calls
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 8: Monitor multiple repositories with regex
export GITHUB_ACCOUNT="prometheus"
export REPO_REGEX="(prometheus|alertmanager|node_exporter|blackbox_exporter)"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 9: Group releases by stability (stable, beta, rc)
export GITHUB_ACCOUNT="kubernetes"
export RELEASE_GROUP_PATTERNS="stable:^v?[0-9]+\.[0-9]+\.[0-9]+$,beta:.*-beta.*,rc:.*-rc.*,alpha:.*-alpha.*"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 10: Group releases by major version
export GITHUB_ACCOUNT="prometheus"
export RELEASE_GROUP_PATTERNS="v1:^v?1\.,v2:^v?2\.,v3:^v?3\."
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Example 11: Group releases by semantic versioning pattern
export GITHUB_ACCOUNT="grafana"
export RELEASE_GROUP_PATTERNS="patch:^v?[0-9]+\.[0-9]+\.[1-9][0-9]*$,minor:^v?[0-9]+\.[1-9][0-9]*\.0$,major:^v?[1-9][0-9]*\.0\.0$"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Note: To get a GitHub token:
# 1. Go to GitHub Settings → Developer settings → Personal access tokens
# 2. Generate a new token with 'public_repo' scope
# 3. Copy the token and set it in GITHUB_TOKEN