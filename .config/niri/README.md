# INSTALL

```sh
sudo pacman -S niri xwayland-satellite xdg-desktop-portal-gnome
mkdir -p ~/.config/niri/scripts
curl -fsSL https://raw.githubusercontent.com/dxdxffgg99/dotfiles/main/.config/niri/config.kdl > ~/.config/niri/config.kdl
curl -fsSL https://raw.githubusercontent.com/dxdxffgg99/dotfiles/main/.config/niri/scripts/refresh-rate.sh > ~/.config/niri/scripts/refresh-rate.sh
chmod +x ~/.config/niri/scripts/refresh-rate.sh
```

tty1 로그인 시 niri 를 띄우려면 `.zprofile` 도 필요합니다.
