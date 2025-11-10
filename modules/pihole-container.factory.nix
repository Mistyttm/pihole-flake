{ piholeFlake
,
}:
{ config
, pkgs
, lib
, options
, ...
}:
let
  inherit (import ../lib/util.nix { inherit lib; })
    extractContainerEnvVars
    extractContainerFTLEnvVars
    ;

  cfg = config.services.pihole;
  hostUserCfg = config.users.users.${cfg.container.user};
  tmpDirIsResetAtBoot = config.boot.tmp.cleanOnBoot || config.boot.tmpOnTmpfs;
in
{
  imports = [
    ./container-config.nix
    ./pihole-config.nix
  ];

  options.services.pihole = {
    enable = lib.mkEnableOption "PiHole as a rootless podman container";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          builtins.length hostUserCfg.subUidRanges > 0 && builtins.length hostUserCfg.subGidRanges > 0;
        message = ''
          The host user most have configured subUidRanges & subGidRanges as pihole is running in a rootless podman container.
        '';
      }
    ];

    warnings =
      (lib.optional (!cfg.container.enableLingering) ''
        If lingering is not enabled for the host user which is running the pihole container then he service might be stopped when no user session is active.

        Set `services.pihole.container.enableLingering` to `true` to manage systemd's linger setting through the `linger-flake` dependency.
        Set it to "suppressWarning" if you manage lingering in a different way.
      '')
      ++ (lib.optional (!tmpDirIsResetAtBoot && !cfg.container.suppressTmpDirWarning) ''
        Rootless podman can leave traces in `/tmp` after shutdown which can break the startup of new containers at the next boot.
        See https://github.com/containers/podman/issues/4057 for details.

        To avoid problems consider to clean `/tmp` of any left-overs from podman before the next startup.
        The NixOS config options `boot.tmp.cleanOnBoot` or `boot.tmpOnTmpfs` can be helpful.
        Enabling either of these disables this warning.
        Otherwise you can also set `services.pihole.container.suppressTmpDirWarning` to `true` to disable the warning.
      '');

    users.users.${cfg.container.user}.linger = lib.mkIf cfg.container.enableLingering true;

    # Create volumes directory with proper ownership using tmpfiles.d
    systemd.tmpfiles.rules = lib.mkIf cfg.container.persistVolumes [
      "d ${cfg.container.volumesPath} 0755 ${cfg.container.user} ${hostUserCfg.group} -"
      "d ${cfg.container.volumesPath}/etc-pihole 0755 ${cfg.container.user} ${hostUserCfg.group} -"
      "d ${cfg.container.volumesPath}/etc-dnsmasq.d 0755 ${cfg.container.user} ${hostUserCfg.group} -"
    ];

    systemd.services."pihole-rootless-container" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];

      # required to make `newuidmap` available to the systemd service (see https://github.com/NixOS/nixpkgs/issues/138423)
      path = [
        "/run/wrappers"
        "/run/current-system/sw/bin"
      ];

      serviceConfig =
        let
          containerEnvVars = extractContainerEnvVars options.services.pihole cfg;
          containerFTLEnvVars = extractContainerFTLEnvVars cfg;

          myScript = pkgs.writeShellScript "run-pihole.sh" ''
            WEBPASSWORD=$(cat ${cfg.web.passwordFile})
            ${pkgs.podman}/bin/podman run \
                        --rm \
                        --rmi \
                        --name="${cfg.container.name}" \
                        ${
                          if cfg.container.persistVolumes then
                            ''
                              -v ${cfg.container.volumesPath}/etc-pihole:/etc/pihole \
                              -v ${cfg.container.volumesPath}/etc-dnsmasq.d:/etc/dnsmasq.d \
                            ''
                          else
                            ""
                        } \
                        ${
                          if cfg.container.dnsPort != null then
                            ''
                              -p ${toString cfg.container.dnsPort}:53/tcp \
                              -p ${toString cfg.container.dnsPort}:53/udp \
                            ''
                          else
                            ""
                        } \
                        ${
                          if cfg.container.dhcpPort != null then
                            ''
                              -p ${toString cfg.container.dhcpPort}:67/udp \
                            ''
                          else
                            ""
                        } \
                        ${
                          if cfg.container.webPort != null then
                            ''
                              -p ${toString cfg.container.webPort}:80/tcp \
                            ''
                          else
                            ""
                        } \
                        ${
                          if cfg.web.passwordFile != "" then
                            ''
                              -e WEBPASSWORD=$WEBPASSWORD \
                            ''
                          else
                            ""
                        } \
                        ${
                          lib.strings.concatStringsSep " \\\n" (
                            map (envVar: "  -e '${envVar.name}=${toString envVar.value}'") (
                              containerEnvVars ++ containerFTLEnvVars
                            )
                          )
                        } \
                        docker-archive:${piholeFlake.packages.${pkgs.system}.piholeImage}
          '';
        in
        {
          ExecStartPre = lib.mkIf cfg.container.persistVolumes [
            ''${pkgs.podman}/bin/podman rm --ignore "${cfg.container.name}"''
          ];

          ExecStart = "${myScript}";
          User = "${cfg.container.user}";
        };

      postStop = ''
        while ${pkgs.podman}/bin/podman container exists "${cfg.container.name}"; do
          ${pkgs.coreutils-full}/bin/sleep 2;
        done
      '';
    };
  };
}
