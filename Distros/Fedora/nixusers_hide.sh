#!/bin/bash

# Create AccountsService directory if it doesn't exist
sudo mkdir -p /var/lib/AccountsService/users

# Loop through nixbld1 to nixbld32 and mark each as a system account
for i in {1..32}; do
  echo -e "[User]\nSystemAccount=true" | sudo tee /var/lib/AccountsService/users/nixbld$i > /dev/null
done

echo "✅ All nixbld users marked as system accounts."

# Optional: Restart SDDM or GDM to apply changes
read -p "Restart display manager now? (sddm/gdm/none): " dm
case "$dm" in
  sddm) sudo systemctl restart sddm ;;
  gdm) sudo systemctl restart gdm ;;
  *) echo "⏳ Skipped restart. You can reboot or restart manually." ;;
esac
