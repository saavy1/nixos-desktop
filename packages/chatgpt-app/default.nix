# Compatibility wrapper and rolling installer for OpenAI's official Linux app.
#
# The application payload deliberately lives outside the Nix store and is
# fetched from OpenAI's mutable `latest` URL. This keeps the rapidly moving app
# unpinned while Nix still provides its FHS runtime and desktop integration.
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
  installRoot = "\${XDG_DATA_HOME:-$HOME/.local/share}/chatgpt-app";

  updater = writeShellApplication {
    name = "chatgpt-update";
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
      url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"

      mkdir -p "$root/releases"
      exec 9>"$root/update.lock"
      if ! flock --exclusive --nonblock 9; then
        echo "ChatGPT is running; deferring update"
        exit 0
      fi

      work="$(mktemp -d "$root/update.XXXXXX")"
      trap 'rm -rf "$work"' EXIT

      curl_args=(
        --fail
        --location
        --silent
        --show-error
        --retry 3
        --etag-save "$work/etag"
        --output "$work/chatgpt.deb"
      )
      if [[ -s "$root/etag" && -x "$root/current/usr/lib/chatgpt/ChatGPT" ]]; then
        curl_args+=(--etag-compare "$root/etag")
      fi
      curl "''${curl_args[@]}" "$url"

      # curl creates no output file when the ETag receives HTTP 304.
      if [[ ! -s "$work/chatgpt.deb" ]]; then
        echo "ChatGPT is already current"
        exit 0
      fi

      mkdir "$work/ar" "$work/payload"
      (
        cd "$work/ar"
        ar x "$work/chatgpt.deb"
      )
      data_archives=("$work"/ar/data.tar.*)
      control_archives=("$work"/ar/control.tar.*)
      if [[ ''${#data_archives[@]} -ne 1 || ! -f "''${data_archives[0]}" || \
            ''${#control_archives[@]} -ne 1 || ! -f "''${control_archives[0]}" ]]; then
        echo "Official package did not contain exactly one data and control archive" >&2
        exit 1
      fi
      version="$(tar -xOf "''${control_archives[0]}" ./control | sed -n 's/^Version: //p')"
      tar -xf "''${data_archives[0]}" -C "$work/payload"

      executable="$work/payload/usr/lib/chatgpt/ChatGPT"
      icon="$work/payload/usr/share/pixmaps/chatgpt.png"
      if [[ ! -x "$executable" || ! -s "$icon" ]]; then
        echo "Official package is missing the expected executable or icon" >&2
        exit 1
      fi

      digest="$(sha256sum "$work/chatgpt.deb")"
      digest="''${digest%% *}"
      release="$root/releases/$digest"
      if [[ ! -d "$release" ]]; then
        mv "$work/payload" "$release"
      fi

      ln -sfn "releases/$digest" "$root/current.new"
      mv -Tf "$root/current.new" "$root/current"
      install -Dm644 "$release/usr/share/pixmaps/chatgpt.png" \
        "$HOME/.local/share/icons/hicolor/512x512/apps/chatgpt.png"
      mv "$work/etag" "$root/etag"

      for old_release in "$root"/releases/*; do
        [[ "$old_release" == "$release" ]] || rm -rf "$old_release"
      done

      echo "Installed ChatGPT $version"
    '';
  };

  launcher = writeShellApplication {
    name = "chatgpt-launch";
    runtimeInputs = [
      libnotify
      util-linux
    ];
    text = ''
      root="${installRoot}"
      executable="$root/current/usr/lib/chatgpt/ChatGPT"
      if [[ ! -x "$executable" ]]; then
        message="ChatGPT is not installed yet; run chatgpt-update"
        echo "$message" >&2
        notify-send "ChatGPT" "$message" || true
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
    name = "chatgpt";
    runScript = "${launcher}/bin/chatgpt-launch";
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
    name = "chatgpt";
    desktopName = "ChatGPT";
    genericName = "AI assistant";
    comment = "ChatGPT and Codex by OpenAI";
    exec = "chatgpt %U";
    icon = "chatgpt";
    categories = [
      "Utility"
      "Development"
    ];
    startupNotify = true;
    mimeTypes = [ "x-scheme-handler/codex" ];
  };
in
symlinkJoin {
  name = "chatgpt-app";
  paths = [
    fhs
    updater
    desktopItem
  ];
  meta = {
    description = "Rolling installer and FHS wrapper for OpenAI's official ChatGPT/Codex Linux app";
    homepage = "https://openai.com/codex/";
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
