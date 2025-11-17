#!/bin/bash
#
# GitHub Downloads Prometheus Exporter
# A bash-based exporter for GitHub repository release download statistics
#

# Set strict error handling
set -euo pipefail

# Source configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Default configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
GITHUB_ACCOUNT="${GITHUB_ACCOUNT:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
REPO_REGEX="${REPO_REGEX:-.*}"
RELEASE_REGEX="${RELEASE_REGEX:-.*}"
ASSET_REGEX="${ASSET_REGEX:-.*}"
RELEASE_GROUP_PATTERNS="${RELEASE_GROUP_PATTERNS:-}"  # Comma-separated group:regex pairs
METRICS_PREFIX="${METRICS_PREFIX:-github_downloads}"
CACHE_TTL="${CACHE_TTL:-300}"  # 5 minutes cache by default
RATE_LIMIT_DELAY="${RATE_LIMIT_DELAY:-1}"  # 1 second delay between API calls

# Cache directory
CACHE_DIR="${CACHE_DIR:-/tmp/github-downloads-exporter}"
mkdir -p "$CACHE_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to check if cache file is valid
is_cache_valid() {
    local cache_file="$1"
    local ttl="$2"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local cache_time
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    
    if (( current_time - cache_time < ttl )); then
        return 0
    else
        return 1
    fi
}

# Function to make GitHub API request with rate limiting and caching
github_api_request() {
    local url="$1"
    local cache_key="$2"
    local cache_file="$CACHE_DIR/${cache_key}.json"
    
    # Check cache first
    if is_cache_valid "$cache_file" "$CACHE_TTL"; then
        cat "$cache_file"
        return 0
    fi
    
    # Prepare curl command
    local curl_cmd="curl -s -L"
    
    # Add authorization if token is provided
    if [[ -n "$GITHUB_TOKEN" ]]; then
        curl_cmd="$curl_cmd -H 'Authorization: token $GITHUB_TOKEN'"
    fi
    
    # Add User-Agent header
    curl_cmd="$curl_cmd -H 'User-Agent: prometheus-github-downloads-exporter'"
    
    # Make the request with rate limiting
    sleep "$RATE_LIMIT_DELAY"
    
    log "Making API request to: $url"
    
    # Execute the request and handle errors
    local response
    local http_code
    response=$(eval "$curl_cmd -w '%{http_code}' '$url'" 2>/dev/null)
    http_code="${response: -3}"
    response="${response%???}"
    
    case "$http_code" in
        "200")
            # Success - cache the response
            echo "$response" > "$cache_file"
            echo "$response"
            ;;
        "403")
            log "ERROR: API rate limit exceeded or forbidden access"
            echo "[]"
            ;;
        "404")
            log "WARNING: Resource not found: $url"
            echo "[]"
            ;;
        *)
            log "ERROR: API request failed with HTTP $http_code: $url"
            echo "[]"
            ;;
    esac
}

# Function to format Prometheus metric
format_metric() {
    local metric_name="$1"
    local value="$2"
    local labels="$3"
    local help="$4"
    local type="${5:-gauge}"
    
    echo "# HELP ${METRICS_PREFIX}_${metric_name} ${help}"
    echo "# TYPE ${METRICS_PREFIX}_${metric_name} ${type}"
    if [[ -n "$labels" ]]; then
        echo "${METRICS_PREFIX}_${metric_name}{${labels}} ${value}"
    else
        echo "${METRICS_PREFIX}_${metric_name} ${value}"
    fi
}

# Function to escape label values
escape_label_value() {
    local value="$1"
    # Escape backslashes, quotes, and newlines
    echo "$value" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# Function to determine release group based on tag name
# Returns the group name if tag matches a pattern, otherwise returns "other"
get_release_group() {
    local tag_name="$1"
    
    # If no group patterns are defined, return "all"
    if [[ -z "$RELEASE_GROUP_PATTERNS" ]]; then
        echo "all"
        return 0
    fi
    
    # Parse group patterns: "stable:^v?[0-9]+\.[0-9]+\.[0-9]+$,beta:.*-beta.*,rc:.*-rc.*"
    IFS=',' read -ra PATTERNS <<< "$RELEASE_GROUP_PATTERNS"
    for pattern in "${PATTERNS[@]}"; do
        if [[ "$pattern" == *":"* ]]; then
            local group_name="${pattern%%:*}"
            local group_regex="${pattern#*:}"
            
            if [[ "$tag_name" =~ $group_regex ]]; then
                echo "$group_name"
                return 0
            fi
        fi
    done
    
    # Default group if no patterns match
    echo "other"
}

# Function to get repositories based on account/repo configuration
get_repositories() {
    local repos_json=""
    
    if [[ -n "$GITHUB_REPO" && -n "$GITHUB_ACCOUNT" ]]; then
        # Single repository mode
        local repo_url="${GITHUB_API_URL}/repos/${GITHUB_ACCOUNT}/${GITHUB_REPO}"
        local repo_data
        repo_data=$(github_api_request "$repo_url" "repo_${GITHUB_ACCOUNT}_${GITHUB_REPO}")
        
        # Wrap single repo in array format
        if [[ "$repo_data" != "[]" && -n "$repo_data" ]]; then
            repos_json="[$repo_data]"
        else
            repos_json="[]"
        fi
    elif [[ -n "$GITHUB_ACCOUNT" ]]; then
        # All repositories for account mode
        local repos_url="${GITHUB_API_URL}/users/${GITHUB_ACCOUNT}/repos?per_page=100"
        repos_json=$(github_api_request "$repos_url" "repos_${GITHUB_ACCOUNT}")
    else
        log "ERROR: Either GITHUB_ACCOUNT or both GITHUB_ACCOUNT and GITHUB_REPO must be specified"
        echo "[]"
        return 1
    fi
    
    # Filter repositories by regex
    if [[ "$REPO_REGEX" != ".*" ]]; then
        echo "$repos_json" | jq -r --arg regex "$REPO_REGEX" '
            [.[] | select(.name | test($regex))]
        '
    else
        echo "$repos_json"
    fi
}

# Function to get releases for a repository
get_repository_releases() {
    local repo_full_name="$1"
    local releases_url="${GITHUB_API_URL}/repos/${repo_full_name}/releases?per_page=100"
    local cache_key="releases_$(echo "$repo_full_name" | tr '/' '_')"
    
    local releases_json
    releases_json=$(github_api_request "$releases_url" "$cache_key")
    
    # Filter releases by regex
    if [[ "$RELEASE_REGEX" != ".*" ]]; then
        echo "$releases_json" | jq -r --arg regex "$RELEASE_REGEX" '
            [.[] | select(.tag_name | test($regex))]
        '
    else
        echo "$releases_json"
    fi
}

# Function to collect download metrics for all repositories
collect_download_metrics() {
    local repos_json
    repos_json=$(get_repositories)
    
    if [[ "$repos_json" == "[]" || -z "$repos_json" ]]; then
        log "No repositories found or accessible"
        return 1
    fi
    
    local total_downloads=0
    local total_releases=0
    local total_assets=0
    
    # Initialize group tracking arrays
    declare -A group_downloads=()
    declare -A group_releases=()
    declare -A group_assets=()
    
    # Process each repository
    while IFS='|' read -r repo_full_name repo_name repo_description; do
        log "Processing repository: $repo_full_name"
        
        local releases_json
        releases_json=$(get_repository_releases "$repo_full_name")
        
        if [[ "$releases_json" == "[]" ]]; then
            log "No releases found for repository: $repo_full_name"
            continue
        fi
        
        local repo_total_downloads=0
        local repo_releases=0
        local repo_assets=0
        
        # Process each release
        while IFS='|' read -r tag_name release_name published_at prerelease draft; do
            if [[ "$draft" == "true" ]]; then
                continue  # Skip draft releases
            fi
            
            repo_releases=$((repo_releases + 1))
            local release_total_downloads=0
            
            # Determine release group
            local release_group
            release_group=$(get_release_group "$tag_name")
            
            # Initialize group counters if not set
            [[ -z "${group_downloads[$release_group]:-}" ]] && group_downloads[$release_group]=0
            [[ -z "${group_releases[$release_group]:-}" ]] && group_releases[$release_group]=0
            [[ -z "${group_assets[$release_group]:-}" ]] && group_assets[$release_group]=0
            
            # Process assets for this release
            while IFS='|' read -r asset_name download_count asset_size content_type; do
                # Filter assets by regex
                if [[ ! "$asset_name" =~ $ASSET_REGEX ]]; then
                    continue
                fi
                
                repo_assets=$((repo_assets + 1))
                release_total_downloads=$((release_total_downloads + download_count))
                
                # Escape label values
                local escaped_repo_name escaped_tag_name escaped_asset_name escaped_release_name
                escaped_repo_name=$(escape_label_value "$repo_name")
                escaped_tag_name=$(escape_label_value "$tag_name")
                escaped_asset_name=$(escape_label_value "$asset_name")
                escaped_release_name=$(escape_label_value "$release_name")
                
                # Escape group name
                local escaped_release_group
                escaped_release_group=$(escape_label_value "$release_group")
                
                # Asset download count metric with group
                local labels="repository=\"$escaped_repo_name\",tag=\"$escaped_tag_name\",asset=\"$escaped_asset_name\",release_name=\"$escaped_release_name\",prerelease=\"$prerelease\",release_group=\"$escaped_release_group\""
                format_metric "asset_downloads_total" "$download_count" "$labels" "Total downloads for a specific asset" "counter"
                
                # Asset size metric with group
                format_metric "asset_size_bytes" "$asset_size" "$labels" "Size of the asset in bytes"
                
                # Update group counters
                group_downloads[$release_group]=$((group_downloads[$release_group] + download_count))
                group_assets[$release_group]=$((group_assets[$release_group] + 1))
                
                echo ""
            done < <(echo "$releases_json" | jq -r --arg tag "$tag_name" '.[] | select(.tag_name == $tag) | .assets[] | "\(.name)|\(.download_count)|\(.size)|\(.content_type // "")"')
            
            # Release total downloads metric
            if [[ $release_total_downloads -gt 0 ]]; then
                local escaped_repo_name escaped_tag_name escaped_release_name escaped_release_group
                escaped_repo_name=$(escape_label_value "$repo_name")
                escaped_tag_name=$(escape_label_value "$tag_name")
                escaped_release_name=$(escape_label_value "$release_name")
                escaped_release_group=$(escape_label_value "$release_group")
                
                local release_labels="repository=\"$escaped_repo_name\",tag=\"$escaped_tag_name\",release_name=\"$escaped_release_name\",prerelease=\"$prerelease\",release_group=\"$escaped_release_group\""
                format_metric "release_downloads_total" "$release_total_downloads" "$release_labels" "Total downloads for a specific release" "counter"
                echo ""
            fi
            
            # Update group release count
            group_releases[$release_group]=$((group_releases[$release_group] + 1))
            
            repo_total_downloads=$((repo_total_downloads + release_total_downloads))
        done < <(echo "$releases_json" | jq -r '.[] | "\(.tag_name)|\(.name // "")|\(.published_at)|\(.prerelease)|\(.draft)"')
        
        # Repository summary metrics
        local escaped_repo_name
        escaped_repo_name=$(escape_label_value "$repo_name")
        local repo_labels="repository=\"$escaped_repo_name\""
        
        format_metric "repository_downloads_total" "$repo_total_downloads" "$repo_labels" "Total downloads for a repository" "counter"
        format_metric "repository_releases_count" "$repo_releases" "$repo_labels" "Number of releases for a repository"
        format_metric "repository_assets_count" "$repo_assets" "$repo_labels" "Number of assets for a repository"
        echo ""
        
        total_downloads=$((total_downloads + repo_total_downloads))
        total_releases=$((total_releases + repo_releases))
        total_assets=$((total_assets + repo_assets))
    done < <(echo "$repos_json" | jq -r '.[] | "\(.full_name)|\(.name)|\(.description // "")"')
    
    # Release group summary metrics
    if [[ ${#group_downloads[@]} -gt 0 ]]; then
        echo ""
        for group in "${!group_downloads[@]}"; do
            # Skip the "other" group in metrics output
            if [[ "$group" == "other" ]]; then
                continue
            fi
            
            local escaped_group
            escaped_group=$(escape_label_value "$group")
            local group_labels="release_group=\"$escaped_group\""
            
            format_metric "group_downloads_total" "${group_downloads[$group]}" "$group_labels" "Total downloads for release group" "counter"
            format_metric "group_releases_count" "${group_releases[$group]}" "$group_labels" "Number of releases in group"
            format_metric "group_assets_count" "${group_assets[$group]}" "$group_labels" "Number of assets in group"
            echo ""
        done
    fi
    
    # Global summary metrics
    format_metric "total_downloads" "$total_downloads" "" "Total downloads across all repositories" "counter"
    format_metric "total_releases" "$total_releases" "" "Total number of releases across all repositories"
    format_metric "total_assets" "$total_assets" "" "Total number of assets across all repositories"
}

# Function to collect API rate limit metrics
collect_rate_limit_metrics() {
    local rate_limit_url="${GITHUB_API_URL}/rate_limit"
    local rate_limit_json
    rate_limit_json=$(github_api_request "$rate_limit_url" "rate_limit")
    
    if [[ "$rate_limit_json" != "[]" && -n "$rate_limit_json" ]]; then
        local core_limit core_remaining core_reset
        core_limit=$(echo "$rate_limit_json" | jq -r '.resources.core.limit // 0')
        core_remaining=$(echo "$rate_limit_json" | jq -r '.resources.core.remaining // 0')
        core_reset=$(echo "$rate_limit_json" | jq -r '.resources.core.reset // 0')
        
        format_metric "api_rate_limit" "$core_limit" "" "GitHub API rate limit"
        format_metric "api_rate_remaining" "$core_remaining" "" "GitHub API remaining requests"
        format_metric "api_rate_reset_timestamp" "$core_reset" "" "GitHub API rate limit reset timestamp"
    fi
}

# Function to collect exporter metrics
collect_exporter_metrics() {
    local start_time end_time duration
    start_time=$(date +%s)
    
    # Collect main metrics
    collect_download_metrics
    echo ""
    collect_rate_limit_metrics
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo ""
    format_metric "scrape_duration_seconds" "$duration" "" "Time spent scraping GitHub API" "gauge"
    format_metric "scrape_timestamp" "$end_time" "" "Timestamp of last successful scrape" "gauge"
}

# Main function to collect and output all metrics
collect_metrics() {
    # Validate configuration
    if [[ -z "$GITHUB_ACCOUNT" ]]; then
        log "ERROR: GITHUB_ACCOUNT must be specified"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log "ERROR: jq not found in PATH. Please install jq for JSON parsing."
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        log "ERROR: curl not found in PATH. Please install curl."
        exit 1
    fi
    
    # Output metrics header
    echo "# GitHub Downloads Exporter Metrics"
    echo "# Generated at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    if [[ -n "$GITHUB_ACCOUNT" ]]; then
        echo "# Account: $GITHUB_ACCOUNT"
    fi
    if [[ -n "$GITHUB_REPO" ]]; then
        echo "# Repository: $GITHUB_REPO"
    fi
    if [[ "$REPO_REGEX" != ".*" ]]; then
        echo "# Repository filter: $REPO_REGEX"
    fi
    if [[ "$RELEASE_REGEX" != ".*" ]]; then
        echo "# Release filter: $RELEASE_REGEX"
    fi
    if [[ "$ASSET_REGEX" != ".*" ]]; then
        echo "# Asset filter: $ASSET_REGEX"
    fi
    if [[ -n "$RELEASE_GROUP_PATTERNS" ]]; then
        echo "# Release groups: $RELEASE_GROUP_PATTERNS"
    fi
    echo ""
    
    # Collect all metrics
    collect_exporter_metrics
}

# Handle command line arguments
case "${1:-collect}" in
    "collect"|"metrics"|"")
        collect_metrics
        ;;
    "test")
        log "Testing GitHub API connection..."
        if [[ -z "$GITHUB_ACCOUNT" ]]; then
            log "ERROR: GITHUB_ACCOUNT must be specified for testing"
            exit 1
        fi
        
        # Test API connectivity
        test_url="${GITHUB_API_URL}/users/${GITHUB_ACCOUNT}"
        test_response=$(github_api_request "$test_url" "test_${GITHUB_ACCOUNT}")
        
        if [[ "$test_response" != "[]" && -n "$test_response" ]]; then
            account_name=$(echo "$test_response" | jq -r '.name // .login')
            log "SUCCESS: Connected to GitHub API"
            log "Account: $account_name"
            
            # Test rate limit
            collect_rate_limit_metrics > /dev/null
            log "Rate limit check successful"
            exit 0
        else
            log "ERROR: Cannot connect to GitHub API or account not found"
            exit 1
        fi
        ;;
    "clean-cache")
        log "Cleaning cache directory: $CACHE_DIR"
        rm -rf "$CACHE_DIR"/*
        log "Cache cleaned"
        ;;
    "version")
        echo "GitHub Downloads Exporter v1.0.0"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [collect|test|clean-cache|version|help]"
        echo ""
        echo "Commands:"
        echo "  collect     - Collect and output Prometheus metrics (default)"
        echo "  test        - Test connection to GitHub API"
        echo "  clean-cache - Clean the cache directory"
        echo "  version     - Show exporter version"
        echo "  help        - Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  GITHUB_TOKEN           - GitHub API token (optional, but recommended)"
        echo "  GITHUB_ACCOUNT         - GitHub account/organization name (required)"
        echo "  GITHUB_REPO            - Specific repository name (optional, defaults to all repos)"
        echo "  REPO_REGEX             - Regex to filter repositories (default: .*)"
        echo "  RELEASE_REGEX          - Regex to filter releases (default: .*)"
        echo "  ASSET_REGEX            - Regex to filter assets (default: .*)"
        echo "  RELEASE_GROUP_PATTERNS - Comma-separated group:regex pairs for release grouping"
        echo "  METRICS_PREFIX         - Metrics prefix (default: github_downloads)"
        echo "  CACHE_TTL              - Cache TTL in seconds (default: 300)"
        echo "  RATE_LIMIT_DELAY       - Delay between API calls in seconds (default: 1)"
        ;;
    *)
        log "ERROR: Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac