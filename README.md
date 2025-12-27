# dotfiles
Stow-managed configs for Hyprland, Waybar, scripts.

## Bootstrap
sudo pacman -S git stow
git clone git@github.com:nextlineIO/dotfiles.git ~/dotfiles
cd ~/dotfiles && stow hypr waybar scripts

## Management

```bash
cd ~/dotfiles
git add -A
git commit -m "Update nvim config"
git push
```

Or as a one-liner:

```bash
cd ~/dotfiles && git add -A && git commit -m "Update nvim config" && git push
```

If you want to see what changed first:

```bash
cd ~/dotfiles
git status
git diff
```
