# Ensure /etc/sddm.conf exists
sudo touch /etc/sddm.conf

# Generate comma-separated list of nixbld users
nixbld_list=$(printf "nixbld%s," {1..32} | sed 's/,$//')

# Add or update the [Users] section with HideUsers
if grep -q "^

\[Users\]

" /etc/sddm.conf; then
  # If [Users] section exists, update or append HideUsers
  sudo sed -i "/^

\[Users\]

/,/^

\[.*\]

/ s/^HideUsers=.*/HideUsers=$nixbld_list/" /etc/sddm.conf || \
  echo "HideUsers=$nixbld_list" | sudo tee -a /etc/sddm.conf > /dev/null
else
  # If no [Users] section, add it
  echo -e "\n[Users]\nHideUsers=$nixbld_list" | sudo tee -a /etc/sddm.conf > /dev/null
fi

echo "✅ Updated /etc/sddm.conf to hide nixbld users."
