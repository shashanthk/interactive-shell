#!/bin/bash

# Define Paths
home_path="$HOME"
ssh_dir="$home_path/.ssh.bak"
ssh_config_file="$ssh_dir/config"

# GitHub SSH Settings
github_url="ssh.github.com"
github_port=443
github_user="git"
github_ssh_key_page="https://github.com/settings/ssh/new"

# Prompt for Username
while [[ -z "$username" ]]; do
    read -p "Please enter your name: " username
    [[ -z "$username" ]] && echo "Name cannot be empty. Please try again."
done

# Normalize username
username_lowercase=$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
name_lower=$(echo "$username_lowercase" | tr '_' '-')
ssh_key_file="$ssh_dir/id_${username_lowercase}"
ssh_pub_key_file="${ssh_key_file}.pub"

# GitHub Configuration Block
github_config=$(cat <<EOF
# GitHub configuration
Host ${name_lower}-github
    HostName ${github_url}
    User ${github_user}
    Port ${github_port}
    IdentityFile ${ssh_key_file}
EOF
)

# Ensure ~/.ssh Directory Exists
mkdir -p "$ssh_dir"

# Check if SSH key file already exists
if [[ -f "$ssh_key_file" ]]; then
    read -p "SSH key already exists. Overwrite? (y/n) [default: n]: " overwrite_choice
    overwrite_choice="${overwrite_choice:-n}"

    if [[ "$overwrite_choice" =~ ^[Yy]$ ]]; then
        echo "Generating new SSH key..."
        ssh-keygen -t ed25519 -f "$ssh_key_file" -N "" || { echo "SSH key generation failed"; exit 1; }
    else
        echo "Skipping key generation."
    fi
else
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -f "$ssh_key_file" -N "" || { echo "SSH key generation failed"; exit 1; }
fi

# Ensure ~/.ssh/config exists
[[ ! -f "$ssh_config_file" ]] && touch "$ssh_config_file"

# Append configuration if not already present
if ! grep -q "Host ${name_lower}-github" "$ssh_config_file"; then
    echo -e "\n$github_config" >> "$ssh_config_file"
    echo "GitHub SSH configuration added."
else
    echo "GitHub SSH configuration already exists. Skipping update."
fi

# Show Config
echo -e "\nUpdated ${ssh_config_file}:"
echo "#######################################################################################################"
cat "$ssh_config_file"
echo "#######################################################################################################"

# Display Public Key for GitHub
echo -e "\nCopy and paste this key to ${github_ssh_key_page} \n"
cat "$ssh_pub_key_file"
echo -e "\nNow, clone repositories using:\n"
echo -e "git clone git@${name_lower}-github:<repo_owner_name>/<repo_name>.git\n"
