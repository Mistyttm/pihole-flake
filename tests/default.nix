{ pkgs ? import <nixpkgs> { }
, piholeFlake ? ../.
}:

let
  # Import the pihole module from the flake
  piholeModule = import ../modules/pihole-container.factory.nix {
    inherit piholeFlake;
  };

  makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
{
  basic = makeTest {
    name = "pihole-basic";
    
    nodes.machine = { config, pkgs, lib, ... }: {
      imports = [ piholeModule ];

      # Basic system configuration
      boot.loader.grub.enable = false;
      fileSystems."/" = lib.mkDefault {
        device = "/dev/vda";
        fsType = "ext4";
      };

      # Create test user for running Pi-hole container
      users.users.pihole = {
        isNormalUser = true;
        uid = 1000;
        subUidRanges = [{ startUid = 100000; count = 65536; }];
        subGidRanges = [{ startGid = 100000; count = 65536; }];
      };

      # Enable Pi-hole with minimal configuration
      services.pihole = {
        enable = true;
        
        container = {
          user = "pihole";
          enableLingering = true;
          name = "pihole-test";
          persistVolumes = false;
          dnsPort = 5353;
          webPort = 8080;
          suppressTmpDirWarning = true;
        };

        timezone = "UTC";
        
        web = {
          password = "testpassword";
        };
      };

      # Enable podman for rootless containers
      virtualisation.podman.enable = true;

      # Clean tmp on boot
      boot.tmp.cleanOnBoot = true;

      # Open firewall for testing
      networking.firewall.enable = false;

      virtualisation.diskSize = 4096;
      virtualisation.memorySize = 2048;
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Check that the pihole user exists
      machine.succeed("id pihole")
      
      # Verify user has subuid/subgid ranges
      machine.succeed("grep '^pihole:' /etc/subuid")
      machine.succeed("grep '^pihole:' /etc/subgid")
      
      # Check that lingering is enabled
      machine.succeed("test -f /var/lib/systemd/linger/pihole")
      
      # Verify the systemd service exists
      machine.succeed("systemctl cat pihole-rootless-container")
      
      # Check service is set to run as the pihole user
      machine.succeed("systemctl show pihole-rootless-container | grep '^User=pihole'")
      
      # Verify podman is available
      machine.succeed("which podman")
      
      print("✓ All basic tests passed!")
    '';
  } { inherit pkgs; };

  containerOptions = makeTest {
    name = "pihole-container-options";
    
    nodes.machine = { config, pkgs, lib, ... }: {
      imports = [ piholeModule ];

      boot.loader.grub.enable = false;
      fileSystems."/" = lib.mkDefault {
        device = "/dev/vda";
        fsType = "ext4";
      };

      users.users.piholeuser = {
        isNormalUser = true;
        uid = 1001;
        subUidRanges = [{ startUid = 200000; count = 65536; }];
        subGidRanges = [{ startGid = 200000; count = 65536; }];
      };

      services.pihole = {
        enable = true;
        
        container = {
          user = "piholeuser";
          enableLingering = true;
          name = "custom-pihole-name";
          persistVolumes = true;
          volumesPath = "/var/lib/pihole-data";
          dnsPort = 5353;
          dhcpPort = 6767;
          webPort = 8080;
          suppressTmpDirWarning = true;
        };

        timezone = "America/New_York";
        interface = "tap0";
        
        web = {
          password = "securepass123";
          theme = "default-dark";
          layout = "traditional";
        };
        
        dns = {
          upstreamServers = [ "1.1.1.1" "8.8.8.8" ];
          dnssec = true;
          bogusPriv = false;
          fqdnRequired = false;
        };
        
        queryLogging = true;
        temperatureUnit = "f";
      };

      virtualisation.podman.enable = true;
      boot.tmp.cleanOnBoot = true;
      networking.firewall.enable = false;
      virtualisation.diskSize = 4096;
      virtualisation.memorySize = 2048;
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Verify custom user is used
      machine.succeed("id piholeuser")
      machine.succeed("systemctl show pihole-rootless-container | grep '^User=piholeuser'")
      
      # Check that volumes directory exists when persistVolumes is enabled
      machine.succeed("test -d /var/lib/pihole-data")
      
      # Verify lingering is enabled for custom user
      machine.succeed("test -f /var/lib/systemd/linger/piholeuser")
      
      print("✓ Container options test passed!")
    '';
  } { inherit pkgs; };

  dhcpConfiguration = makeTest {
    name = "pihole-dhcp-config";
    
    nodes.machine = { config, pkgs, lib, ... }: {
      imports = [ piholeModule ];

      boot.loader.grub.enable = false;
      fileSystems."/" = lib.mkDefault {
        device = "/dev/vda";
        fsType = "ext4";
      };

      users.users.pihole = {
        isNormalUser = true;
        uid = 1000;
        subUidRanges = [{ startUid = 100000; count = 65536; }];
        subGidRanges = [{ startGid = 100000; count = 65536; }];
      };

      services.pihole = {
        enable = true;
        
        container = {
          user = "pihole";
          enableLingering = true;
          name = "pihole-dhcp-test";
          dnsPort = 5353;
          dhcpPort = 6767;
          webPort = 8080;
          suppressTmpDirWarning = true;
        };

        dhcp = {
          enable = true;
          start = "192.168.1.10";
          end = "192.168.1.250";
          router = "192.168.1.1";
          leasetime = 24;
          domain = "test.local";
          ipv6 = false;
          rapid-commit = true;
        };
        
        revServer = {
          enable = true;
          domain = "test.local";
          target = "192.168.1.1";
          cidr = "192.168.1.0/24";
        };
        
        ftl = {
          LOCAL_IPV4 = "192.168.1.100";
          PRIVACYLEVEL = "0";
        };
      };

      virtualisation.podman.enable = true;
      boot.tmp.cleanOnBoot = true;
      networking.firewall.enable = false;
      virtualisation.diskSize = 4096;
      virtualisation.memorySize = 2048;
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Verify service is defined
      machine.succeed("systemctl cat pihole-rootless-container")
      
      # Check that DHCP port is configured in the service (host port 6767 maps to container port 67)
      service_config = machine.succeed("systemctl cat pihole-rootless-container")
      # The port format is host:container, so we look for the DHCP container port 67
      assert "-p" in service_config and "67/udp" in service_config, "DHCP port not configured"
      
      print("✓ DHCP configuration test passed!")
    '';
  } { inherit pkgs; };

  flattenedStructure = makeTest {
    name = "pihole-flattened-structure";
    
    nodes.machine = { config, pkgs, lib, ... }: {
      imports = [ piholeModule ];

      boot.loader.grub.enable = false;
      fileSystems."/" = lib.mkDefault {
        device = "/dev/vda";
        fsType = "ext4";
      };

      users.users.pihole = {
        isNormalUser = true;
        subUidRanges = [{ startUid = 100000; count = 65536; }];
        subGidRanges = [{ startGid = 100000; count = 65536; }];
      };

      # Test that old structure is NOT accepted (should fail if uncommented)
      # services.pihole.hostConfig.user = "pihole";  # This should not work
      # services.pihole.piholeConfig.web.password = "test";  # This should not work
      
      # Test that new flattened structure works
      services.pihole = {
        enable = true;
        
        # New container structure (not hostConfig)
        container.user = "pihole";
        container.enableLingering = true;
        container.dnsPort = 5353;
        container.webPort = 8080;
        container.suppressTmpDirWarning = true;
        
        # Flattened options (not under piholeConfig)
        timezone = "UTC";
        interface = "tap0";
        web.password = "test123";
        web.theme = "default-dark";
        dns.upstreamServers = [ "1.1.1.1" ];
        queryLogging = true;
        temperatureUnit = "c";
      };

      virtualisation.podman.enable = true;
      boot.tmp.cleanOnBoot = true;
      networking.firewall.enable = false;
      virtualisation.diskSize = 4096;
      virtualisation.memorySize = 2048;
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Verify the service exists with new structure
      machine.succeed("systemctl cat pihole-rootless-container")
      
      # Check user is correct
      machine.succeed("systemctl show pihole-rootless-container | grep '^User=pihole'")
      
      print("✓ Flattened structure test passed!")
      print("✓ New option names (container, not hostConfig) work correctly!")
    '';
  } { inherit pkgs; };

  # Note: The assertions test is commented out because it tests a failing configuration
  # which would prevent the flake from evaluating. In a real scenario, the module
  # would catch the missing subuid/subgid during system build and report an error.
  # 
  # To test assertions manually, try building a system with a user missing subuid/subgid:
  # The error message will be:
  # "The host user must have configured subUidRanges & subGidRanges as pihole
  #  is running in a rootless podman container."
}
