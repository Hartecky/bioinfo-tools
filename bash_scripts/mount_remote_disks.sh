#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <cdd|genome>"
  exit 1
fi

# Argument for the type of mount
mount_type=$1

# Execute the appropriate sshfs commands based on the argument
# replace XXX with correct ip address
if [ "$mount_type" == "cdd" ]; then

  echo "Mounting CDD data..."
  sshfs bah@XXX.XXX.XXX.XXX:/cdd-data /media/bartomniej/cdd_data

elif [ "$mount_type" == "genome" ]; then

  echo "Mounting Genome data..."
  sshfs bhofman@XXX.XXX.XXX.XXX:/mnt/ /media/bartomniej/genome_mnt/
  sshfs bhofman@XXX.XXX.XXX.XXX:/home/bhofman /media/bartomniej/genome_home/
  
else
  echo "Invalid argument. Use 'cdd' or 'genome'."
  exit 1
fi

