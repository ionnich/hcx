# nix-darwin module for one Mac in the hybrid setup: agents live in herdr-core (hc); hcx keeps
# them resumable and mirrors this Mac's agents into its Rex. Needs home-manager's nix-darwin
# module for the skill and Rex files. See docs/operations.md for what each option does.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.hcx;
  inherit (lib) mkIf mkMerge mkOption mkEnableOption types;
  home = "/Users/${cfg.user}";
  pkgs' = pkgs.callPackage ./packages.nix { };
  bool = default: description: mkOption { type = types.bool; inherit default description; };
  openAtLogin = app: {
    serviceConfig = {
      ProgramArguments = [ "/usr/bin/open" "-g" "-j" "-a" app ];
      RunAtLoad = true;
      LimitLoadToSessionType = "Aqua";
    };
  };
in
{
  options.services.hcx = {
    enable = mkEnableOption "hcx: resumable omp agents in herdr-core, mirrored into Rex";

    user = mkOption {
      type = types.str;
      default = config.system.primaryUser;
      description = "The account whose agents hcx manages.";
    };

    board = bool false ''
      Give this Mac's Rex `agents` session a `board` tab listing every agent on every machine
      this Mac's core sees. Turn it on for one Mac only, the one you work at.
    '';

    rexSync = bool true ''
      Mirror this Mac's own agents into its Rex `agents` session (a tab per space).
    '';

    openHerdrAtLogin = bool true ''
      Open Herdr.app (hidden) at login. The app starts herdr-core with your login environment,
      which every agent inherits; hcx waits for that core instead of starting its own.
    '';

    openRexAtLogin = bool false ''
      Open Rex.app (hidden) at login, which starts its server. For a Mac that hosts agents for
      other machines' Rex.app (the Studio); a Mac you sit at can open Rex itself.
    '';

    skill = bool true ''
      Install the `hc` agent skill at ~/.agents/skills/hc/SKILL.md (omp reads it).
    '';

    rexActions = bool true ''
      Install the Rex actions at ~/.config/rex/hcx.lua. Load them from init.lua with
      dofile(os.getenv("HOME") .. "/.config/rex/hcx.lua").
    '';

    guardRexAutostart = bool false ''
      Set REX_AUTOSTART=0 in fish, so an ssh:// Rex client can never start a second Rex server
      outside the login session (for a Mac whose Rex.app owns the server).
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [ pkgs'.hcx pkgs'.hc-tui ];

      # Every minute: adopt omp terminals, record their conversation files and commands, resume
      # them once per boot, and keep the Rex `agents` session in step.
      launchd.user.agents.hcx = {
        command = "${pkgs'.hcx}/bin/hcx tick";
        serviceConfig = {
          RunAtLoad = true;
          StartInterval = 60;
          LimitLoadToSessionType = "Aqua";
          EnvironmentVariables = {
            # hc, rex and omp live in ~/.local/bin; jq, lsof and sysctl come with macOS.
            PATH = "${home}/.local/bin:${config.environment.systemPath}:/usr/bin:/bin:/usr/sbin:/sbin";
            HCX_BOARD = if cfg.board then "1" else "0";
            HCX_REX_SYNC = if cfg.rexSync then "1" else "0";
          };
          StandardOutPath = "/tmp/hcx_${cfg.user}.log";
          StandardErrorPath = "/tmp/hcx_${cfg.user}.log";
        };
      };
    }

    (mkIf cfg.openHerdrAtLogin { launchd.user.agents.herdr-app = openAtLogin "${home}/Applications/Herdr.app"; })
    (mkIf cfg.openRexAtLogin { launchd.user.agents.rex-app = openAtLogin "/Applications/Rex.app"; })

    {
      home-manager.users.${cfg.user} = {
        home.file.".agents/skills/hc/SKILL.md" = mkIf cfg.skill { source = ../skills/hc/SKILL.md; };
        xdg.configFile."rex/hcx.lua" = mkIf cfg.rexActions { source = ../rex/hcx.lua; };
        xdg.configFile."fish/conf.d/rex-autostart.fish" = mkIf cfg.guardRexAutostart {
          text = ''
            # From the hcx module: Rex.app owns this Mac's Rex server; never let an ssh:// client
            # or the CLI start a second one outside the login session.
            set -gx REX_AUTOSTART 0
          '';
        };
      };
    }
  ]);
}
