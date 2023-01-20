#!/bin/bash

# Start the timer
start=$(date +%s)

# Download a file from a web server using wget
wget -O /dev/null http://speedtest.wdc01.softlayer.com/downloads/test500.zip

# End the timer
end=$(date +%s)

# Calculate the download speed
download_speed=$((500 / (end - start)))

# Print the download speed
echo "Download speed: $download_speed Kb/s"

# Create a test file of size 500MB
dd if=/dev/zero of=test500.zip bs=1M count=500

# Start the timer
start=$(date +%s)

# Upload the file using curl
curl --upload-file test500.zip https://transfer.sh/test500.zip

# End the timer
end=$(date +%s)

# Calculate the upload speed
upload_speed=$((500 / (end - start)))

# Print the upload speed
echo "Upload speed: $upload_speed Kb/s"

# Remove the test file
rm test500.zip
