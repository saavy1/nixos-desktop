{
  programs.hyprlock = {
    enable = true;
    package = null;
    settings = {
      general.ignore_empty_input = true;
      animations.enabled = false;
    };
  };

  services.hypridle = {
    enable = true;
    package = null;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms(\"on\")'";
      };
      listener = [
        {
          timeout = 180;
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms(\"off\")'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms(\"on\")'";
        }
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
