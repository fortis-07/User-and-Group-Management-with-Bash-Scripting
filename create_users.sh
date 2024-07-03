#!/bin/bash

# Check if running as root
if [[ $UID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if the input file is provided
if [ $# -ne 1 ]; then
    echo "Use: $0 <filename>"
    exit 1
fi
FILENAME=$1

# Ensure proper permissions for password file
# Create directories for logs and password storage if they don't exist
mkdir -p /var/secure
PASSFILE="/var/secure/user_passwords.txt"
touch $PASSFILE
chmod 600 $PASSFILE
mkdir -p /var/log
LOGFILE="/var/log/user_management.log"
touch $LOGFILE
chmod 644 /var/log/user_management.log
echo "User management started at $(date)" > $LOGFILE

# Loop through each line in the input file
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)
    if [ -z "$username" ]; then
        continue
    fi
    if id -u "$username"; then
        echo "User $username already exists" | tee -a $LOGFILE
    else
        useradd -m -s /bin/bash -U "$username"
        echo "User $username created with personal group $username" | tee -a $LOGFILE
    fi
    IFS=',' read -r -a group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" >/dev/null 2>&1; then
            groupadd "$group"
            echo "Group $group created" | tee -a $LOGFILE
        fi
        usermod -aG "$group" "$username"
        echo "User $username added to group $group" | tee -a $LOGFILE
    done

#Function to generate random passwords
#The chpasswd command reads a list of user name and password pairs from standard input and updates the system password file
    password=$(openssl rand -base64 12)
    echo "$username:$password" | chpasswd
    echo "Password set for user $username" | tee -a $LOGFILE
    
    #Store the password securely
    #The password is stored in the /var/secure/user_passwords.txt file
    #The file is created if it does not exist
    #The file permissions are set to 600
    echo "$username,$password" >> $PASSFILE
done < "$FILENAME"
echo "User management creation completed at $(date)" | tee -a $LOGFILE
