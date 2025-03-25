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

# Function to generate SSH key
generate_ssh_key() {
    local key_file="$1"
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -f "$key_file" -N "" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error: SSH key generation failed."
        return 1
    fi
    return 0
}

# Prompt message
prompt_message="Please enter your name (letters, numbers, spaces, underscores, dashes only): "

# Check if a username is provided as a command-line argument else show a prompt
if [[ -n "$1" ]]; then
    username="$1"
else

    read -rp "$prompt_message" username

    while true; do
        if [[ "$username" =~ ^[a-zA-Z0-9_[:space:]-]+$ ]]; then
            break
        else
            printf "\e[31m\nInvalid name. Allowed characters:\n  a-z A-Z 0-9 _ spaces -\n\e[0m\n"
            read -rp "$prompt_message" username
        fi
    done
fi

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
    read -rp "SSH key already exists. Overwrite? (y/n) [default: n]: " overwrite_choice
    overwrite_choice="${overwrite_choice:-n}"
    if [[ "$overwrite_choice" =~ ^[Yy]$ ]]; then
        if ! generate_ssh_key "$ssh_key_file"; then
            exit 1
        fi
    else
        echo "Skipping key generation."
    fi
else
    if ! generate_ssh_key "$ssh_key_file"; then
        exit 1
    fi
fi

# Ensure ~/.ssh/config exists
[[ ! -f "$ssh_config_file" ]] && touch "$ssh_config_file"

# Append configuration if not already present
if ! grep -q "Host ${name_lower}-github" "$ssh_config_file" >/dev/null; then
    echo -e "\n$github_config" >> "$ssh_config_file"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to write to config file"
        exit 1
    fi
    echo "GitHub SSH configuration added."
else
    echo "GitHub SSH configuration already exists. Skipping update."
fi

# Set correct permissions
chmod 700 "$ssh_dir"
chmod 600 "$ssh_key_file"
chmod 644 "$ssh_pub_key_file"

# Show Config
printf "\nUpdated %s:\n" "$ssh_config_file"
echo "#######################################################################################################"
cat "$ssh_config_file"
echo "#######################################################################################################"

# Display Public Key for GitHub
printf "\nCopy and paste this key to \e[34;4m%s\e[0m\n" "$github_ssh_key_page"
printf "\n\e[92m$(cat "$ssh_pub_key_file")\e[0m\n"
printf "\nNow, clone repositories using:\n\ngit clone git@%s:<repo_owner_name>/<repo_name>.git\n\n" "$name_lower-github"

printf "You can test the connection by running:\n\nssh -T git@%s\n\n" "$name_lower-github"