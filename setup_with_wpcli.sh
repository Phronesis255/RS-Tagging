#!/bin/bash

# Input file
INPUT_FILE="classified_integrated.csv"

# Output to log file
LOG_FILE="update_tags_log.txt"

# Ensure the log file is empty
> "$LOG_FILE"

# Check if csvkit is installed, and install it if necessary
if ! command -v csvcut &> /dev/null; then
  echo "csvkit not found. Installing..."
  pip install csvkit || { echo "Failed to install csvkit. Please install it manually."; exit 1; }
fi

# Check if WP-CLI is installed, and install it if necessary
if ! command -v wp &> /dev/null; then
  echo "WP-CLI not found. Installing..."
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar || { echo "Failed to download WP-CLI. Please install it manually."; exit 1; }
  chmod +x wp-cli.phar
  sudo mv wp-cli.phar /usr/local/bin/wp || { echo "Failed to move WP-CLI to /usr/local/bin. Please check permissions."; exit 1; }
  echo "WP-CLI installed successfully."
fi

echo "Both csvkit and WP-CLI are installed. Starting the tag update process..."

# Process the CSV file using csvkit
csvcut -c 1,2,3 "$INPUT_FILE" | tail -n +2 | while IFS=, read -r TITLE URL TOPIC; do
  # Remove quotes around TITLE, URL, and TOPIC (csvkit handles embedded commas already)
  TITLE=$(echo "$TITLE" | sed 's/^"//;s/"$//')
  URL=$(echo "$URL" | sed 's/^"//;s/"$//')
  TOPIC=$(echo "$TOPIC" | sed 's/^"//;s/"$//')

  # Extract the slug from the URL
  SLUG=$(basename "$URL")
  
  # Get the post ID using the slug
  POST_ID=$(wp post list --name="$SLUG" --fields=ID --format=ids)
  
  # Check if the post ID is valid
  if [ -n "$POST_ID" ]; then
    # Split the tags by comma and loop through each tag
    IFS=',' read -ra TAGS <<< "$TOPIC"
    for TAG in "${TAGS[@]}"; do
      # Trim whitespace around the tag
      TAG=$(echo "$TAG" | xargs)
      
      # Add the tag to the post
      wp post term add "$POST_ID" post_tag "$TAG" >> "$LOG_FILE" 2>&1
    done
    
    echo "Tags added to Post ID $POST_ID (Slug: $SLUG) with Tags: $TOPIC"
  else
    echo "No Post found for URL: $URL" >> "$LOG_FILE"
  fi
done

echo "Tag update process completed. Check $LOG_FILE for details."
