#!/bin/bash

# This resource is provided as a convenience for Level users. We cannot 
# guarantee it will work in all environments. Please test before deploying 
# to your production environment. We welcome contributions to our community 
# library

# Level Library
# https://level.io/library/script-linux-debian-kernel-cleanup

# Get the current kernel version
current_kernel=$(uname -r)

# List all installed kernels, sorted in version order, and exclude the current kernel
installed_kernels=$(ls /lib/modules | grep -v "$current_kernel" | sort -V)

# Keep the two most recent kernels as backups
kernels_to_keep=$(echo "$installed_kernels" | tail -n 2)

# Create a list of kernels to remove, excluding the kernels to keep
kernels_to_remove=$(comm -23 <(echo "$installed_kernels") <(echo "$kernels_to_keep"))

if [ -n "$kernels_to_remove" ]; then
  # Remove each kernel in the list
  for kernel in $kernels_to_remove
  do
    echo "Removing $kernel"
    sudo apt-get remove -y "linux-image-$kernel"
    sudo apt-get purge -y "linux-image-$kernel"
    sudo rm -rf "/lib/modules/$kernel"
  done

  # Finally, clean up any remaining unused packages
  sudo apt-get autoremove -y
  echo "Kernel cleanup complete!"

  # Count the number of kernels removed
  num_kernels_to_remove=$(echo "$kernels_to_remove" | wc -l)
else
  echo "No kernels to remove."
  num_kernels_to_remove=0
fi

echo "Number of kernels removed: $num_kernels_to_remove"
