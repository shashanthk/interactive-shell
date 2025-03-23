### Using the scripts

1. GitHub SSH key generator

    If downloaded to local system, run like below:

        ./git_ssh_key_automation.sh "John Doe"
    
    Remote execution without downloading:

        curl -o- https://raw.githubusercontent.com/shashanthk/interactive-shell/main/git_ssh_key_automation.sh | bash -s "John Doe"