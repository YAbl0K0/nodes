(
  echo "=== CPU Info ===" && lscpu
  echo -e "\n=== GPU Info ===" && nvidia-smi
  echo -e "\n=== RAM Info ===" && free -h
  echo -e "\n=== Storage Info ===" && lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
  echo -e "\n=== System Info ===" && uname -a
) > server_specs.txt
