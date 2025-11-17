# GitHub Downloads Prometheus Exporter

A lightweight, bash-based Prometheus exporter for GitHub repository release download statistics. This exporter uses only bash, curl, jq, and socat to provide comprehensive download metrics for monitoring with Prometheus and Grafana.

## Features

- **Pure Bash Implementation**: No external dependencies except `socat`, `curl`, and `jq`
- **Comprehensive Metrics**: Exports GitHub download statistics including:
  - Download counts per asset, release, and repository
  - Asset sizes and metadata
  - Repository and release counts
  - GitHub API rate limit status
- **Regex-Based Filtering**: Filter repositories, releases, and assets using regular expressions
- **Flexible Configuration**: Monitor single repositories, all repositories for an account, or filtered subsets
- **HTTP Server**: Built-in HTTP server using socat for serving metrics
- **Caching**: Built-in caching to reduce API calls and respect rate limits
- **Rate Limiting**: Configurable delays between API calls to avoid rate limits
- **Systemd Integration**: Ready-to-use systemd service file
- **GitHub Enterprise Support**: Works with GitHub Enterprise instances

## Quick Start

### Prerequisites

- GitHub account or organization to monitor
- `socat` package installed
- `curl` and `jq` packages installed
- GitHub API token (optional but recommended for higher rate limits)
- Prometheus server for scraping metrics

### Basic Installation

1. Clone the repository:
```bash
git clone https://github.com/itefixnet/prometheus-github-downloads-exporter.git
cd prometheus-github-downloads-exporter
```

2. Configure the exporter:
```bash
# Edit config.sh or set environment variables
export GITHUB_ACCOUNT="your-account-name"
export GITHUB_TOKEN="your-github-token"  # Optional but recommended
```

3. Test the exporter:
```bash
./github-downloads-exporter.sh test
```

4. Start the HTTP server:
```bash
./http-server.sh start
```

5. Access metrics at `http://localhost:9168/metrics`

### System Installation

For production deployment, install as a system service:

```bash
# Create user and directories
sudo useradd -r -s /bin/false github-downloads-exporter
sudo mkdir -p /opt/github-downloads-exporter

# Copy files
sudo cp *.sh /opt/github-downloads-exporter/
sudo cp config.sh /opt/github-downloads-exporter/
sudo cp github-downloads-exporter.conf /opt/github-downloads-exporter/
sudo cp github-downloads-exporter.service /etc/systemd/system/

# Set permissions
sudo chown -R github-downloads-exporter:github-downloads-exporter /opt/github-downloads-exporter
sudo chmod +x /opt/github-downloads-exporter/*.sh

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable github-downloads-exporter
sudo systemctl start github-downloads-exporter
```

## Configuration

### Environment Variables

The exporter can be configured using environment variables or configuration files:

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_TOKEN` | _(none)_ | GitHub API token (strongly recommended) |
| `GITHUB_ACCOUNT` | _(required)_ | GitHub account/organization name |
| `GITHUB_REPO` | _(none)_ | Specific repository name (optional) |
| `GITHUB_API_URL` | `https://api.github.com` | GitHub API URL (for Enterprise) |
| `REPO_REGEX` | `.*` | Regex to filter repositories |
| `RELEASE_REGEX` | `.*` | Regex to filter releases |
| `ASSET_REGEX` | `.*` | Regex to filter assets |
| `RELEASE_GROUP_PATTERNS` | _(none)_ | Comma-separated group:regex pairs for grouping releases |
| `LISTEN_PORT` | `9168` | HTTP server port |
| `LISTEN_ADDRESS` | `0.0.0.0` | HTTP server bind address |
| `METRICS_PREFIX` | `github_downloads` | Prometheus metrics prefix |
| `CACHE_TTL` | `300` | Cache TTL in seconds |
| `RATE_LIMIT_DELAY` | `1` | Delay between API calls in seconds |

### Configuration Files

1. **`config.sh`**: Shell configuration file (sourced by scripts)
2. **`github-downloads-exporter.conf`**: Systemd environment file

### GitHub Token Setup

While not required, using a GitHub token is strongly recommended to increase API rate limits:

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate a new token with `public_repo` scope (or `repo` for private repositories)
3. Set the token: `export GITHUB_TOKEN="your-token-here"`

## Metrics

The exporter provides the following comprehensive Prometheus metrics:

### Asset-Level Metrics
- `github_downloads_asset_downloads_total{repository="repo",tag="v1.0",asset="file.tar.gz",release_name="Release 1.0",prerelease="false",release_group="stable"}` - Downloads per asset
- `github_downloads_asset_size_bytes{repository="repo",tag="v1.0",asset="file.tar.gz",release_name="Release 1.0",prerelease="false",release_group="stable"}` - Asset file size

### Release-Level Metrics
- `github_downloads_release_downloads_total{repository="repo",tag="v1.0",release_name="Release 1.0",prerelease="false",release_group="stable"}` - Total downloads per release

### Repository-Level Metrics
- `github_downloads_repository_downloads_total{repository="repo"}` - Total downloads per repository
- `github_downloads_repository_releases_count{repository="repo"}` - Number of releases per repository
- `github_downloads_repository_assets_count{repository="repo"}` - Number of assets per repository

### Release Group Metrics
- `github_downloads_group_downloads_total{release_group="stable"}` - Total downloads per release group
- `github_downloads_group_releases_count{release_group="stable"}` - Number of releases per group
- `github_downloads_group_assets_count{release_group="stable"}` - Number of assets per group

### Global Metrics
- `github_downloads_total_downloads` - Total downloads across all monitored repositories
- `github_downloads_total_releases` - Total number of releases across all repositories
- `github_downloads_total_assets` - Total number of assets across all repositories

### API Rate Limit Metrics
- `github_downloads_api_rate_limit` - GitHub API rate limit
- `github_downloads_api_rate_remaining` - Remaining API calls
- `github_downloads_api_rate_reset_timestamp` - Rate limit reset timestamp

### Exporter Metrics
- `github_downloads_scrape_duration_seconds` - Time spent scraping GitHub API
- `github_downloads_scrape_timestamp` - Timestamp of last successful scrape

## Usage Examples

### Monitor Specific Repository

```bash
export GITHUB_ACCOUNT="prometheus"
export GITHUB_REPO="prometheus"
./github-downloads-exporter.sh collect
```

### Monitor All Repositories for Account

```bash
export GITHUB_ACCOUNT="kubernetes"
./github-downloads-exporter.sh collect
```

### Filter with Regex Patterns

```bash
# Monitor only client libraries
export GITHUB_ACCOUNT="kubernetes"
export REPO_REGEX=".*client.*"

# Monitor only stable releases
export RELEASE_REGEX="^v?[0-9]+\.[0-9]+\.[0-9]+$"

# Monitor only binary assets
export ASSET_REGEX="\.(tar\.gz|zip|deb|rpm|exe)$"
```

### Group Releases by Type

```bash
# Group releases into stable, beta, rc, and alpha categories
export GITHUB_ACCOUNT="kubernetes"
export RELEASE_GROUP_PATTERNS="stable:^v?[0-9]+\.[0-9]+\.[0-9]+$,beta:.*-beta.*,rc:.*-rc.*,alpha:.*-alpha.*"

# Group releases by major version
export GITHUB_ACCOUNT="prometheus"
export RELEASE_GROUP_PATTERNS="v1:^v?1\.,v2:^v?2\.,v3:^v?3\."

# Group releases by semantic versioning type (patch, minor, major)
export GITHUB_ACCOUNT="grafana"
export RELEASE_GROUP_PATTERNS="patch:^v?[0-9]+\.[0-9]+\.[1-9][0-9]*$,minor:^v?[0-9]+\.[1-9][0-9]*\.0$,major:^v?[1-9][0-9]*\.0\.0$"
```

### Manual Testing

```bash
# Test connection
./github-downloads-exporter.sh test

# Collect metrics once
./github-downloads-exporter.sh collect

# Start HTTP server manually
./http-server.sh start

# Test HTTP endpoints
curl http://localhost:9168/metrics
curl http://localhost:9168/health
curl http://localhost:9168/
```

### Prometheus Configuration

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'github-downloads-exporter'
    static_configs:
      - targets: ['localhost:9168']
    scrape_interval: 5m  # GitHub data doesn't change frequently
    scrape_timeout: 60s   # API calls can take time
    metrics_path: /metrics
    
  # Multiple instances
  - job_name: 'github-downloads'
    static_configs:
      - targets: ['server1:9168', 'server2:9168']
        labels:
          environment: 'production'
    scrape_interval: 5m
```

### Grafana Dashboard

The repository includes a comprehensive Grafana dashboard (`grafana-dashboard.json`) with the following features:

**Core Visualizations:**
- **Total Downloads**: Overall download trends across all repositories
- **Top Repositories**: Bar chart showing most popular repositories by downloads
- **Top Releases**: Most downloaded releases across all monitored repositories
- **Top Assets**: Most popular individual assets/files

**Release Grouping Visualizations:**
- **Downloads by Release Group**: Bar chart showing download distribution across groups (stable, beta, rc, etc.)
- **Group Distribution Pie Chart**: Visual breakdown of download percentages per group
- **Release Group Statistics Table**: Detailed stats per group (downloads, releases, assets count)

**Monitoring & Health:**
- **GitHub API Rate Limits**: Current usage and remaining quota
- **Scrape Performance**: Exporter performance metrics
- **Repository Statistics**: Complete overview table

**Interactive Features:**
- **Instance Filter**: Monitor multiple exporter instances
- **Repository Filter**: Focus on specific repositories
- **Release Group Filter**: Filter by release groups (stable, beta, rc, etc.)
- **Time Range Selection**: Analyze trends over different periods

**Installation:**
1. Import `grafana-dashboard.json` into your Grafana instance
2. Configure the Prometheus datasource
3. Use the template variables to filter data as needed

The dashboard automatically adapts to your release grouping configuration and provides insights into adoption patterns across different release types.

## Troubleshooting

### Common Issues

1. **Rate Limit Exceeded**:
   - Add a GitHub token: `export GITHUB_TOKEN="your-token"`
   - Increase `RATE_LIMIT_DELAY` or `CACHE_TTL`
   - Monitor rate limit metrics

2. **API Connection Failed**:
   - Check internet connectivity
   - Verify GitHub account exists
   - Test manually: `curl https://api.github.com/users/ACCOUNT`

3. **No Data Returned**:
   - Verify repository has releases
   - Check regex patterns aren't too restrictive
   - Ensure repository is public (or token has access)

4. **Missing Dependencies**:
   ```bash
   # Install on Ubuntu/Debian
   sudo apt-get install socat curl jq
   
   # Install on CentOS/RHEL
   sudo yum install socat curl jq
   ```

### Logging

- Service logs: `journalctl -u github-downloads-exporter -f`
- Manual logs: Scripts output to stderr
- Enable debug: `LOG_LEVEL=debug`

### Performance Tuning

For high-frequency monitoring:
- Increase `CACHE_TTL` to reduce API calls
- Adjust `RATE_LIMIT_DELAY` based on your rate limits
- Use specific repository monitoring instead of account-wide
- Consider running multiple exporter instances for different accounts

## Development

### Testing

```bash
# Run basic tests
./github-downloads-exporter.sh test
./http-server.sh test

# Test with different configurations
GITHUB_ACCOUNT=prometheus ./github-downloads-exporter.sh test
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly with different GitHub accounts/repositories
4. Submit a pull request

### License

This project is licensed under the BSD 2-Clause License - see the [LICENSE](LICENSE) file for details.

## Support

- GitHub Issues: [https://github.com/itefixnet/prometheus-github-downloads-exporter/issues](https://github.com/itefixnet/prometheus-github-downloads-exporter/issues)
- Documentation: This README and inline script comments

## Use Cases

This exporter is particularly useful for:

- **Open Source Projects**: Track adoption through download metrics
- **Release Management**: Monitor which versions are most popular
- **Asset Performance**: Understand which package formats are preferred
- **Growth Tracking**: Measure project growth over time
- **Release Strategy**: Optimize release cadence based on download patterns

## Alternatives

For more advanced features or different languages, consider:
- [GitHub API directly](https://docs.github.com/en/rest/releases/releases) with custom scripts
- Grafana GitHub datasource plugin
- Custom Prometheus collectors in Go/Python