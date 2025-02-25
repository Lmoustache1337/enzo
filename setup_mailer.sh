#!/bin/bash

# ✅ Make sure the script is being run with sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "⛔ Please run this script as root or with sudo."
  exit 1
fi

# 🔹 Prompt for user inputs
read -p "Enter the custom myhostname (or press Enter for localhost): " myhostname
myhostname=${myhostname:-localhost}

read -p "Enter the sender email address: " sender_email
read -p "Enter the sender name: " sender_name
read -p "Enter the email subject: " email_subject
read -p "Enter the path to your email list file (e.g., emails.txt): " email_list

# 🔹 Update package list and install Postfix & Mailutils
echo "🔄 Updating package list and installing Postfix..."
sudo apt-get update -y
sudo apt-get install postfix mailutils tmux -y

# 🔹 Backup the original Postfix config file
echo "📂 Backing up the original Postfix main.cf..."
sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.backup

# 🔹 Remove the current main.cf to replace with custom config
echo "🛠️ Configuring Postfix..."
sudo rm /etc/postfix/main.cf

# 🛠️ Create a new Postfix main.cf file with the desired configuration
sudo tee /etc/postfix/main.cf > /dev/null <<EOL
myhostname = $myhostname
inet_interfaces = loopback-only
relayhost = 
mydestination = localhost
smtp_sasl_auth_enable = no
smtpd_sasl_auth_enable = no
smtp_tls_security_level = may
EOL

# 🔹 Restart Postfix to apply the changes
echo "🔄 Restarting Postfix service..."
sudo systemctl restart postfix

# 🔹 Create a sample HTML email content (email.html)
echo "📩 Creating email.html with email content..."
cat > email.html <<EOL
<html>
<body>
  <h1>🎁 Exclusive Offer Just for You!</h1>
  <p>Click <a href="https://yourwebsite.com">here</a> to claim your reward.</p>
</body>
</html>
EOL

# 🔹 Create the sending script (send.sh)
echo "📜 Creating send.sh for bulk email sending..."
cat > send.sh <<EOL
#!/bin/bash

EMAIL_LIST="$email_list"
DELAY=5  # Delay to prevent spam detection
LOG_FILE="log.txt"

if [ ! -f "\$EMAIL_LIST" ]; then
  echo "⛔ Error: Email list file (\$EMAIL_LIST) not found!"
  exit 1
fi

while IFS= read -r email; do
  echo "📨 Sending email to: \$email" | tee -a \$LOG_FILE

  cat <<EOF | /usr/sbin/sendmail -t
To: \$email
From: $sender_name <$sender_email>
Subject: $email_subject
MIME-Version: 1.0
Content-Type: text/html

\$(cat email.html)
EOF

  echo "✅ Email sent to: \$email at \$(date)" | tee -a \$LOG_FILE
  sleep \$DELAY
done < "\$EMAIL_LIST"

echo "🎉 All emails sent! Check \$LOG_FILE for details."
EOL

# 🔹 Make the send.sh script executable
chmod +x send.sh

# 🔹 Create a tmux session and run the send.sh script in it
echo "🟢 Starting tmux session for email sending..."
tmux new-session -d -s mail_session "./send.sh"

echo "✅ Your email sending process is running in the background!"
echo "🔗 To reattach to the session, use: tmux attach -t mail_session"
