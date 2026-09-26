# Compatibility wrapper and rolling installer for Anthropic's official
# Claude Desktop Linux app (beta).
#
# The application payload deliberately lives outside the Nix store and is
# resolved from Anthropic's apt repository index at update time. Unlike
# OpenAI's ChatGPT app there is no mutable `latest` URL, so the updater
# follows the repository's own documented lookup: newest amd64 entry in the
# `Packages` index, downloaded from the pool. This keeps the rapidly moving
# app unpinned (per repo policy for this class of app) while Nix still
# provides its FHS runtime and desktop integration.
{
  alsa-lib,
  at-spi2-atk,
  atk,
  binutils,
  buildFHSEnv,
  cairo,
  coreutils,
  cups,
  curl,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gnutar,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libsecret,
  libusb1,
  libxkbcommon,
  libx11,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbfile,
  libxrandr,
  libxrender,
  libxtst,
  libxcb,
  makeDesktopItem,
  mesa,
  nspr,
  nss,
  pango,
  symlinkJoin,
  systemd,
  util-linux,
  vulkan-loader,
  writeShellApplication,
  xdg-utils,
  xz,
}:
let
  installRoot = "\${XDG_DATA_HOME:-$HOME/.local/share}/claude-desktop";
  repoBase = "https://downloads.claude.ai/claude-desktop/apt/stable";
  packagesIndex = "${repoBase}/dists/stable/main/binary-amd64/Packages";

  updater = writeShellApplication {
    name = "claude-desktop-update";
    runtimeInputs = [
      binutils
      coreutils
      curl
      gnutar
      util-linux
      xz
    ];
    text = ''
      root="${installRoot}"

      mkdir -p "$root/releases"
      exec 9>"$root/update.lock"
      if ! flock --exclusive --nonblock 9; then
        echo "Claude Desktop is running; deferring update"
        exit 0
      fi

      work="$(mktemp -d "$root/update.XXXXXX")"
      trap 'rm -rf "$work"' EXIT

      # Same lookup the official install docs use: newest amd64 entry wins.
      if ! index="$(curl --fail --location --silent --show-error --retry 3 \
          "${packagesIndex}")"; then
        echo "Could not fetch the Claude Desktop repository index" >&2
        exit 1
      fi
      newest="$(printf '%s\n' "$index" \
        | grep '^Filename: pool/main/c/claude-desktop/claude-desktop_' \
        | cut -d' ' -f2 | sort -V | tail -n 1)"
      if [[ -z "$newest" ]]; then
        echo "Repository index lists no claude-desktop package for amd64" >&2
        exit 1
      fi
      version="$(basename "$newest" | sed -n 's/^claude-desktop_\(.*\)_amd64\.deb$/\1/p')"
      if [[ -z "$version" ]]; then
        echo "Could not parse a version from '$newest'" >&2
        exit 1
      fi

      if [[ -f "$root/version" && "$(cat "$root/version")" == "$version" && \
            -x "$root/current/usr/lib/claude-desktop/claude-desktop" ]]; then
        echo "Claude Desktop is already current ($version)"
        exit 0
      fi

      curl --fail --location --silent --show-error --retry 3 \
        --output "$work/claude-desktop.deb" "${repoBase}/$newest"

      mkdir "$work/ar" "$work/payload"
      (
        cd "$work/ar"
        ar x "$work/claude-desktop.deb"
      )
      data_archives=("$work"/ar/data.tar.*)
      control_archives=("$work"/ar/control.tar.*)
      if [[ ''${#data_archives[@]} -ne 1 || ! -f "''${data_archives[0]}" || \
            ''${#control_archives[@]} -ne 1 || ! -f "''${control_archives[0]}" ]]; then
        echo "Official package did not contain exactly one data and control archive" >&2
        exit 1
      fi
      tar -xf "''${data_archives[0]}" -C "$work/payload"

      executable="$work/payload/usr/lib/claude-desktop/claude-desktop"
      if [[ ! -x "$executable" ]]; then
        echo "Official package is missing usr/lib/claude-desktop/claude-desktop" >&2
        exit 1
      fi
      shopt -s nullglob
      icon_files=("$work/payload/usr/share/icons/hicolor/"*/apps/claude-desktop.png)
      shopt -u nullglob
      if [[ ''${#icon_files[@]} -eq 0 ]]; then
        echo "Official package is missing its hicolor icons" >&2
        exit 1
      fi

      digest="$(sha256sum "$work/claude-desktop.deb")"
      digest="''${digest%% *}"
      release="$root/releases/$digest"
      if [[ ! -d "$release" ]]; then
        mv "$work/payload" "$release"
      fi

      ln -sfn "releases/$digest" "$root/current.new"
      mv -Tf "$root/current.new" "$root/current"
      mkdir -p "$HOME/.local/share/icons"
      cp -r "$release/usr/share/icons/." "$HOME/.local/share/icons/"
      printf '%s\n' "$version" > "$root/version.new"
      mv -Tf "$root/version.new" "$root/version"

      for old_release in "$root"/releases/*; do
        [[ "$old_release" == "$release" ]] || rm -rf "$old_release"
      done

      echo "Installed Claude Desktop $version"
    '';
  };

  launcher = writeShellApplication {
    name = "claude-desktop-launch";
    runtimeInputs = [
      libnotify
      util-linux
    ];
    text = ''
      root="${installRoot}"
      executable="$root/current/usr/lib/claude-desktop/claude-desktop"
      if [[ ! -x "$executable" ]]; then
        message="Claude Desktop is not installed yet; run claude-desktop-update"
        echo "$message" >&2
        notify-send "Claude Desktop" "$message" || true
        exit 1
      fi

      # A shared lock prevents the rolling updater from replacing resources
      # while Electron is using them. --no-sandbox is required because the
      # extracted Debian chrome-sandbox cannot be root-owned/setuid on NixOS.
      exec flock --shared "$root/update.lock" \
        "$executable" \
        --no-sandbox \
        --ozone-platform=wayland \
        --enable-wayland-ime \
        "$@"
    '';
  };

  fhs = buildFHSEnv {
    name = "claude-desktop";
    runScript = "${launcher}/bin/claude-desktop-launch";
    targetPkgs = pkgs: [
      alsa-lib
      at-spi2-atk
      atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libGL
      libnotify
      libsecret
      libusb1
      libxkbcommon
      mesa
      nspr
      nss
      pango
      systemd
      vulkan-loader
      xdg-utils
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxkbfile
      libxrandr
      libxrender
      libxtst
      libxcb
    ];
  };

  desktopItem = makeDesktopItem {
    name = "claude-desktop";
    desktopName = "Claude";
    genericName = "AI assistant";
    comment = "Desktop application for Claude.ai";
    exec = "claude-desktop %U";
    icon = "claude-desktop";
    categories = [
      "Utility"
      "Development"
    ];
    startupNotify = true;
    startupWMClass = "com.anthropic.Claude";
    mimeTypes = [ "x-scheme-handler/claude" ];
  };
in
symlinkJoin {
  name = "claude-desktop";
  paths = [
    fhs
    updater
    desktopItem
  ];
  meta = {
    description = "Rolling installer and FHS wrapper for Anthropic's official Claude Desktop Linux app (beta)";
    homepage = "https://claude.ai";
    license = lib.licenses.unfree;
    mainProgram = "claude-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
