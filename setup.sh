#!/bin/bash

set -e

echo "=================================="
echo "OpenCode MCP Server Setup"
echo "=================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get opencode config path
if [ -z "$1" ]; then
    DEFAULT_CONFIG="$HOME/.config/opencode/opencode.json"
    read -p "OpenCode config path [default: $DEFAULT_CONFIG]: " CONFIG_PATH
    CONFIG_PATH=${CONFIG_PATH:-$DEFAULT_CONFIG}
else
    CONFIG_PATH="$1"
fi

# Validate config file exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo "[Error] Config file not found: $CONFIG_PATH"
    exit 1
fi

echo "[v] Using config: $CONFIG_PATH"
echo ""

# Backup original config
BACKUP_PATH="${CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "[v] Backed up to: $BACKUP_PATH"
echo ""

# Define MCP servers to install
declare -A MCP_SERVERS=(
    ["filesystem"]="@modelcontextprotocol/server-filesystem|$HOME|Secure file operations"
    ["memory"]="@modelcontextprotocol/server-memory||Knowledge graph-based persistent memory"
    ["search"]="custom-search||Web search using Python server with SearXNG (requires server.py and SEARXNG_URL)"
    ["puppeteer"]="@modelcontextprotocol/server-puppeteer||Browser automation with Puppeteer"
    ["github"]="@modelcontextprotocol/server-github||GitHub repository and issue access (token optional for public repos)"
)

# Let user select which servers to install
echo "Available MCP Servers:"
echo "----------------------"
for key in "${!MCP_SERVERS[@]}"; do
    IFS='|' read -r package path description <<< "${MCP_SERVERS[$key]}"
    if [ "$key" == "filesystem" ] && grep -q "\"filesystem\"" "$CONFIG_PATH"; then
        echo "  ✓ $key (already configured)"
    else
        echo "    $key - $description"
    fi
done
echo ""

read -p "Install all available servers? [Y/n]: " INSTALL_ALL
INSTALL_ALL=${INSTALL_ALL:-Y}

# Build jq filter to add MCP servers
JQ_FILTER='.'
SELECTED_COUNT=0
# Array to store selected servers for dependency setup
declare -a SELECTED_SERVERS=()

for key in "${!MCP_SERVERS[@]}"; do
    # Skip filesystem if already configured
    if [ "$key" == "filesystem" ] && grep -q "\"filesystem\"" "$CONFIG_PATH"; then
        echo "[v] Skipping $key (already configured)"
        continue
    fi

    INSTALL=false

    if [[ "$INSTALL_ALL" =~ ^[Yy]$ ]]; then
        INSTALL=true
    else
        read -p "Install $key? [Y/n]: " INSTALL_INPUT
        if [[ "$INSTALL_INPUT" =~ ^[Yy]*$ ]]; then
            INSTALL=true
        fi
    fi

    if [ "$INSTALL" = true ]; then
        IFS='|' read -r package path description <<< "${MCP_SERVERS[$key]}"
        
        # Check if server requires special config
        if [ -n "$path" ]; then
            # For filesystem, use the provided path
            JQ_FILTER="${JQ_FILTER} | .mcp[\"${key}\"] = {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"${package}\", \"${path}\"]}"
        elif [ "$key" == "search" ]; then
            # For custom search, use python script
            JQ_FILTER="${JQ_FILTER} | .mcp[\"${key}\"] = {\"type\": \"local\", \"command\": [\"$HOME/search-mcp/.venv/bin/python3\", \"${PWD}/custom-search.py\"]}"
        else
            # For other servers, just run npx
            JQ_FILTER="${JQ_FILTER} | .mcp[\"${key}\"] = {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"${package}\"]}"
        fi
        
        echo "[v] Will install: $key ($package)"
        ((++SELECTED_COUNT))
        SELECTED_SERVERS+=("$key")
    fi
done

echo ""

if [ $SELECTED_COUNT -eq 0 ]; then
    echo "No servers selected for installation."
    echo "Backup restored."
    exit 0
fi

read -p "Continue? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    echo "Backup restored."
    exit 0
fi

echo ""
echo "[v] Installing MCP servers..."
echo ""

# Apply jq filter to update config
jq "${JQ_FILTER}" "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"

echo "[v] Updated $SELECTED_COUNT MCP servers in config"
echo ""

# Install and setup dependencies for selected servers
echo "=================================="
echo "Setting up dependencies..."
echo "=================================="
echo ""

# Function to detect OS
get_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

check_and_install_pip() {
    echo "[*] Checking pip and venv..."

    if python3 -m pip --version &> /dev/null && python3 -m venv --help &> /dev/null; then
        echo "[v] pip and venv already installed"
        return
    fi

    OS=$(get_os)

    if [ "$EUID" -eq 0 ]; then
        SUDO=""
    else
        SUDO="sudo"
    fi

    echo "[*] Installing pip and venv for $OS..."

    case $OS in
        ubuntu|debian)
            $SUDO apt-get update -y
            $SUDO apt-get install -y python3-pip python3-venv
            ;;
        fedora|rhel|centos)
            $SUDO dnf install -y python3-pip python3-virtualenv \
            || $SUDO yum install -y python3-pip python3-virtualenv
            ;;
        arch|manjaro)
            $SUDO pacman -S --noconfirm python-pip python-virtualenv
            ;;
        opensuse*)
            $SUDO zypper install -y python3-pip python3-virtualenv
            ;;
        alpine)
            $SUDO apk add --no-cache py3-pip py3-virtualenv
            ;;
        *)
            echo "[!] Unknown OS: $OS"
            echo "[*] Attempting manual pip install..."

            TMPFILE=$(mktemp)
            curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$TMPFILE"
            python3 "$TMPFILE" --break-system-packages
            rm -f "$TMPFILE"
            ;;
    esac

    if python3 -m pip --version &> /dev/null; then
        echo "[v] pip installed"
    else
        echo "[Error] Failed to install pip"
        return 1
    fi

    if python3 -m venv --help &> /dev/null; then
        echo "[v] venv available"
    else
        echo "[Warning] venv not available"
    fi
}

# Function to check and install Docker
check_and_install_docker() {
    if command -v docker &> /dev/null; then
        echo "[v] Docker already installed"
    else
        echo "[Docker] Installing Docker..."
        OS=$(get_os)
        
        case $OS in
            ubuntu|debian)
                # Use Docker's convenience script
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                rm get-docker.sh
                ;;
            fedora)
                sudo dnf install -y docker
                sudo systemctl start docker
                sudo systemctl enable docker
                ;;
            rhel|centos)
                sudo yum install -y docker
                sudo systemctl start docker
                sudo systemctl enable docker
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm docker
                sudo systemctl start docker
                sudo systemctl enable docker
                ;;
            opensuse*)
                sudo zypper install -y docker
                sudo systemctl start docker
                sudo systemctl enable docker
                ;;
            alpine)
                apk add --no-cache docker
                rc-update add docker boot
                service docker start
                ;;
            *)
                echo "[Docker] Unknown OS: $OS, trying generic installation..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                rm get-docker.sh
                ;;
        esac
        echo "[v] Docker installed"
    fi
    
    # Add user to docker group if not already a member
    if ! groups $USER | grep -q docker; then
        echo "[Docker] Adding user to docker group..."
	sudo groupadd docker
        sudo usermod -aG docker $USER
        echo "[v] User added to docker group"
        echo "[!] You may need to log out and log back in for group changes to take effect"
    fi
}

# Function to setup Custom Search
setup_search() {
    echo ""
    echo "--- Custom Search Setup ---"
    
    check_and_install_pip
    mkdir -p ~/search-mcp
    cd ~/search-mcp
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r ${SCRIPT_DIR}/search/requirements.txt
    playwright install
    check_and_install_docker
    
    SEARXNG_DIR="$HOME/searxng"
    SEARXNG_SETTINGS="$SEARXNG_DIR/settings.yml"
    
    mkdir -p "$SEARXNG_DIR"
    
    if [ ! -f "$SEARXNG_SETTINGS" ]; then
        echo "[v] Creating SearXNG settings file..."
        cat > "$SEARXNG_SETTINGS" << 'EOF'
use_default_settings: true

server:
  port: 8080
  bind_address: "0.0.0.0"
  secret_key: "change_this_random_string"
  base_url: false

search:
  safe_search: 0
  formats:
    - html
    - json

engines:
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg

  - name: wikipedia
    engine: wikipedia
    shortcut: wp
EOF
        echo "[v] SearXNG settings created: $SEARXNG_SETTINGS"
    else
        echo "[v] SearXNG settings already exists: $SEARXNG_SETTINGS"
    fi
    
    # Check if container is already running
    if sudo docker ps --filter "name=searxng" --format '{{.Names}}' | grep -q searxng; then
        echo "[v] SearXNG container already running"
        return
    fi
    
    # Check if container exists but stopped
    if sudo docker ps -a --filter "name=searxng" --format '{{.Names}}' | grep -q searxng; then
        echo "Starting existing SearXNG container..."
        sudo docker restart searxng
        echo "[v] SearXNG container started"
        return
    fi
    
    # Run new container with settings mount
    echo "Starting SearXNG container..."
    sudo docker run -d --name searxng -p 8080:8080 -v "$SEARXNG_DIR:/etc/searxng" -e BASE_URL=http://localhost:8080 searxng/searxng
    echo "[v] SearXNG container started on http://localhost:8080"
    echo "[v] Custom search server ready at: ${SCRIPT_DIR}/search/search.py"
}

# Setup dependencies for selected servers
for key in "${SELECTED_SERVERS[@]}"; do
    case $key in
        search)
            setup_search
            ;;
    esac
done

echo ""

echo "=================================="
echo "[v] Setup complete!"
echo "=================================="
echo ""
echo "Summary:"
echo "  - Config file: $CONFIG_PATH"
echo "  - Servers configured: $SELECTED_COUNT"
echo "  - Backup: $BACKUP_PATH"
echo ""
echo "Next steps:"
echo "  1. Restart OpenCode"
echo "  2. For github, optionally set GITHUB_PERSONAL_ACCESS_TOKEN for private repos"
echo ""
echo "Notes:"
echo "  - Some servers will download on first use via npx"
echo "  - SearXNG is running on http://localhost:8080 for search"
echo "  - Custom search server at: ${SCRIPT_DIR}/search/search.py"
echo "  - SQLite database: $HOME/data/database.db"
echo ""
