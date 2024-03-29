#!/bin/bash

home_path=$HOME
ssh_dir=$home_path"/.ssh"
ssh_config_file=$ssh_dir"/config"

github_url="ssh.github.com"
github_port=443
github_user="git"
github_ssh_key_page="https://github.com/settings/ssh/new"

username_prompt_message="Please enter your name: "

# Ask for user's name
read -p "${username_prompt_message}" username

# Ensure the user enters a name
while [[ -z "$username" ]]; do
    read -p "${username_prompt_message}" username
done

# Convert name to lowercase and replace spaces with underscores
username_lowercase=$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
name_lower=$(echo "$username_lowercase" | tr '_' '-')

# Check if ~/.ssh directory exists, if not create it
if [ ! -d $ssh_dir ]; then
    echo "The ${ssh_dir} directory doesn't exist. Creating it..."
    mkdir -p "${ssh_dir}"
else
    echo "The ${ssh_dir} directory already exists. Continuing with next step"
fi

# Check if SSH key file exists for the user
ssh_key_file="${ssh_dir}"/id_"$username_lowercase"

if [ -f "$ssh_key_file" ]; then
    
    read -p "SSH key file already exists. Do you want to continue and overwrite? (y/n): " overwrite_choice

    if [[ $overwrite_choice != "y" && $overwrite_choice != "Y" ]]; then
        echo -e "Exiting...\n"
        exit 1
    fi
fi

# Generate SSH key
echo "Generating SSH key..."
ssh-keygen -t ed25519 -f "$ssh_key_file"

# Check if ~/.ssh/config file exists, if not create it
if [ ! -f "${ssh_config_file}" ]; then
    echo -e "\nCreating ${ssh_config_file} file..."
    touch "${ssh_config_file}"
else 
    echo -e "\nThe ${ssh_config_file} already exists. Continuing with next step"
fi

# Define the GitHub configuration content

if grep -q "IdentityFile ~/.ssh/id_${username_lowercase}" "${ssh_config_file}"; then
    echo "GitHub configuration already exists in ${ssh_config_file}. Skipping appending content."
else
    github_config="\n"
    github_config+="# GitHub configuration\n"
    github_config+="Host ${name_lower}-github\n"
    github_config+="HostName ${github_url}\n"
    github_config+="User ${github_user}\n"
    github_config+="Port ${github_port}\n"
    github_config+="IdentityFile ~/.ssh/id_${username_lowercase}\n"

    # Append GitHub configuration content to ~/.ssh/config
    echo -e "Appending content to ${ssh_config_file}... \n"
    echo -e "$github_config" >> "${ssh_config_file}"
fi

# Show updated content of ~/.ssh/config
echo -e "Content of ${ssh_config_file} file: \n"
echo -e "####################################################################################################### \n"
cat "${ssh_config_file}"
echo -e "####################################################################################################### \n"

echo -e "Copy the content of ${ssh_dir}/id_${username_lowercase}.pub file \n"
cat "${ssh_dir}"/id_"${username_lowercase}".pub

echo -e "\nPaste the above content here ${github_ssh_key_page} \n"

echo -e "Now, you can clone the repositories like below: \n"

echo -e "git clone git@${name_lower}-github:<repo_owner_name>/<repo_name>.git \n"
