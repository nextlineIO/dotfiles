
#!/usr/bin/env bash
# Collect installed power-related packages into ~/power-packages.txt

OUT="$HOME/power-packages.txt"
: > "$OUT"   # clear file

echo "=== TLP ==="              | tee -a "$OUT"
pacman -Qs tlp                 | tee -a "$OUT"
echo                           | tee -a "$OUT"

echo "=== POWER ==="            | tee -a "$OUT"
pacman -Qs power                | tee -a "$OUT"
echo                           | tee -a "$OUT"

echo "=== ACPI ==="             | tee -a "$OUT"
pacman -Qs acpi                 | tee -a "$OUT"
echo                           | tee -a "$OUT"

echo "=== PM (power mgmt) ==="  | tee -a "$OUT"
pacman -Qs pm                   | tee -a "$OUT"
echo                           | tee -a "$OUT"

echo "=== UPOWER ==="           | tee -a "$OUT"
pacman -Qs upower               | tee -a "$OUT"
echo                           | tee -a "$OUT"

echo "=== POWERTOP ==="         | tee -a "$OUT"
pacman -Qs powertop             | tee -a "$OUT"
echo                           | tee -a "$OUT"

echo "Done. Results saved to $OUT"

