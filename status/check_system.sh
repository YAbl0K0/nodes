echo "=== CPU Info ==="
lscpu
echo

echo "=== GPU Info ==="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
else
    lspci -nn | grep VGA
    glxinfo | grep "OpenGL renderer string"
fi
echo

echo "=== RAM Info ==="
free -h
echo

echo "=== Storage Info ==="
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
df -h
echo

echo "=== System Info ==="
uname -a
hostnamectl
echo

echo "=== PCI Devices ==="
lspci
