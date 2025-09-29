# dotfiles
Stow-managed configs for Hyprland, Waybar, scripts.

## Bootstrap
sudo pacman -S git stow
git clone git@github.com:nextlineIO/dotfiles.git ~/dotfiles
cd ~/dotfiles && stow hypr waybar scripts
