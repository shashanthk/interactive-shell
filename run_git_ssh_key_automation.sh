#!/bin/sh

# Detect the actual running shell
if [ -n "$BASH" ]; then
    shell_name="bash"
elif [ -n "$ZSH_VERSION" ]; then
    shell_name="zsh"
elif [ -n "$fish_version" ]; then
    shell_name="fish"
else
    shell_name=$(ps -o comm= -p $$ 2>/dev/null || echo "sh")
fi

echo "Detected shell: $shell_name"

# Set default shell execution command
shell_cmd="sh"

case "$shell_name" in
    zsh) shell_cmd="zsh" ;;
    bash) shell_cmd="bash" ;;
    fish) shell_cmd="fish";;
esac

# Define temporary script location
script_path="/tmp/git_ssh_key_automation.sh"

# # Download the script
echo "Downloading script..."
curl -o "$script_path" -s https://raw.githubusercontent.com/shashanthk/interactive-shell/main/git_ssh_key_automation.sh

# Make it executable
chmod +x "$script_path"

# Execute the script with the detected shell
echo "Executing script..."
$shell_cmd "$script_path"

# Cleanup
echo "Cleaning up..."
rm -f "$script_path"

echo "Done!"
