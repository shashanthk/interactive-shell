package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	githubURL       = "ssh.github.com"
	githubPort      = 443
	githubUser      = "git"
	githubSSHKeyPage = "https://github.com/settings/ssh/new"
	promptMessage   = "Please enter your name (letters, numbers, spaces, underscores, dashes only): "
)

var validUsername = regexp.MustCompile(`^[a-zA-Z0-9_ -]+$`)

func generateSSHKey(keyFile string) error {
	fmt.Println("Generating new SSH key...")
	cmd := exec.Command("ssh-keygen", "-t", "ed25519", "-f", keyFile, "-N", "")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("SSH key generation failed: %w", err)
	}
	return nil
}

func readLine(reader *bufio.Reader) (string, error) {
	line, err := reader.ReadString('\n')
	return strings.TrimRight(line, "\r\n"), err
}

func main() {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: cannot determine home directory: %v\n", err)
		os.Exit(1)
	}

	sshDir := filepath.Join(homeDir, ".ssh")
	sshConfigFile := filepath.Join(sshDir, "config")

	// Determine username
	var username string
	if len(os.Args) > 1 {
		username = os.Args[1]
	} else {
		reader := bufio.NewReader(os.Stdin)
		fmt.Print(promptMessage)
		username, err = readLine(reader)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
			os.Exit(1)
		}

		for !validUsername.MatchString(username) {
			fmt.Print("\033[31m\nInvalid name. Allowed characters:\n  a-z A-Z 0-9 _ spaces -\n\033[0m\n")
			fmt.Print(promptMessage)
			username, err = readLine(reader)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
				os.Exit(1)
			}
		}
	}

	// Normalize username: lowercase, spaces -> underscores
	usernameLower := strings.ToLower(username)
	usernameLower = strings.ReplaceAll(usernameLower, " ", "_")
	// For SSH Host alias: underscores -> dashes
	nameLower := strings.ReplaceAll(usernameLower, "_", "-")

	sshKeyFile := filepath.Join(sshDir, "id_"+usernameLower)
	sshPubKeyFile := sshKeyFile + ".pub"

	// GitHub SSH config block
	githubConfig := fmt.Sprintf(`
# GitHub configuration
Host %s-github
    HostName %s
    User %s
    Port %d
    IdentityFile %s
`, nameLower, githubURL, githubUser, githubPort, sshKeyFile)

	// Ensure ~/.ssh directory exists
	if err := os.MkdirAll(sshDir, 0700); err != nil {
		fmt.Fprintf(os.Stderr, "Error: cannot create %s: %v\n", sshDir, err)
		os.Exit(1)
	}

	// Check if SSH key already exists
	if _, statErr := os.Stat(sshKeyFile); statErr == nil {
		reader := bufio.NewReader(os.Stdin)
		fmt.Print("SSH key already exists. Overwrite? (y/n) [default: n]: ")
		choice, readErr := readLine(reader)
		if readErr != nil {
			fmt.Fprintf(os.Stderr, "Error reading input: %v\n", readErr)
			os.Exit(1)
		}
		if choice == "" {
			choice = "n"
		}
		if strings.ToLower(choice) == "y" {
			if err := generateSSHKey(sshKeyFile); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
		} else {
			fmt.Println("Skipping key generation.")
		}
	} else {
		if err := generateSSHKey(sshKeyFile); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	}

	// Ensure ~/.ssh/config exists
	if _, statErr := os.Stat(sshConfigFile); os.IsNotExist(statErr) {
		f, createErr := os.Create(sshConfigFile)
		if createErr != nil {
			fmt.Fprintf(os.Stderr, "Error: cannot create config file: %v\n", createErr)
			os.Exit(1)
		}
		f.Close()
	}

	// Read existing config to check for duplicate entry
	configData, err := os.ReadFile(sshConfigFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: cannot read config file: %v\n", err)
		os.Exit(1)
	}

	hostEntry := fmt.Sprintf("Host %s-github", nameLower)
	if !strings.Contains(string(configData), hostEntry) {
		f, openErr := os.OpenFile(sshConfigFile, os.O_APPEND|os.O_WRONLY, 0600)
		if openErr != nil {
			fmt.Fprintf(os.Stderr, "Error: Failed to write to config file: %v\n", openErr)
			os.Exit(1)
		}
		_, writeErr := f.WriteString(githubConfig)
		f.Close()
		if writeErr != nil {
			fmt.Fprintf(os.Stderr, "Error: Failed to write to config file: %v\n", writeErr)
			os.Exit(1)
		}
		fmt.Println("GitHub SSH configuration added.")
	} else {
		fmt.Println("GitHub SSH configuration already exists. Skipping update.")
	}

	// Set correct permissions
	if err := os.Chmod(sshDir, 0700); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: failed to set permissions on %s: %v\n", sshDir, err)
	}
	if err := os.Chmod(sshKeyFile, 0600); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: failed to set permissions on %s: %v\n", sshKeyFile, err)
	}
	if err := os.Chmod(sshPubKeyFile, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: failed to set permissions on %s: %v\n", sshPubKeyFile, err)
	}

	// Show updated config
	configData, err = os.ReadFile(sshConfigFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading config: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("\nUpdated %s:\n", sshConfigFile)
	fmt.Println("#######################################################################################################")
	fmt.Print(string(configData))
	fmt.Println("#######################################################################################################")

	// Display public key
	pubKeyData, err := os.ReadFile(sshPubKeyFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading public key: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("\nCopy and paste this key to \033[34;4m%s\033[0m\n", githubSSHKeyPage)
	fmt.Printf("\n\033[92m%s\033[0m\n", strings.TrimSpace(string(pubKeyData)))
	fmt.Printf("\nNow, clone repositories using:\n\ngit clone git@%s-github:<repo_owner_name>/<repo_name>.git\n\n", nameLower)
	fmt.Printf("You can test the connection by running:\n\nssh -T git@%s-github\n\n", nameLower)
}
