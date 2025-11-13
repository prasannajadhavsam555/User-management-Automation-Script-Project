#!/bin/bash

USER_FILE="$1"
PASS_FILE="/var/secure/user_passwords.txt"

# Create secure folder for passwords
mkdir -p /var/secure
touch "$PASS_FILE"
chmod 600 "$PASS_FILE"

# Check if input file is given
if [[ -z "$USER_FILE" ]]; then
    echo "Usage: $0 <user_list_file>"
    exit 1
fi

# Check if file exists
if [[ ! -f "$USER_FILE" ]]; then
    echo "Error: File '$USER_FILE' not found!"
    exit 1
fi

# Read each line from the file
while IFS= read -r line; do
    # Skip empty lines or comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Remove spaces
    line=$(echo "$line" | tr -d '[:space:]')

    # Split username and groups
    IFS=';' read -r username groups <<< "$line"

    # Create group same as username
    if ! getent group "$username" >/dev/null; then
        groupadd "$username"
        echo "Group '$username' created."
    else
        echo "Group '$username' already exists."
    fi

    # Create extra groups if needed
    for g in $(echo "$groups" | tr ',' ' '); do
        if ! getent group "$g" >/dev/null; then
            groupadd "$g"
            echo "Group '$g' created."
        fi
    done

    # Check if user exists
    if id "$username" &>/dev/null; then
        echo "User '$username' already exists, skipping."
        continue
    fi

    # Create user with home directory and groups
    useradd -m -g "$username" -G "$groups" "$username"
    echo "User '$username' created."

    # Set password (12 random characters)
    password=$(tr -dc 'A-Za-z0-9!@#$%&*' </dev/urandom | head -c12)
    echo "$username:$password" | chpasswd
    echo "$username:$password" >> "$PASS_FILE"

    echo "Password set for '$username'."
done < "$USER_FILE"

echo "All users processed successfully!"
