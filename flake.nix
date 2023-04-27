{
  description = "Home Manager configuration";
  inputs = {
    # Where we get most of our software. Giant mono repo with recipes
    # called derivations that say how to build software.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-22.11-darwin";

    # Manages configs links things into your home directory
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    # for python package builds 
    mach-nix.url = "github:davhau/mach-nix";

    # Controls system level software and settings including fonts
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

  };
 outputs = { nixpkgs, nixpkgs-unstable, mach-nix,  home-manager, darwin,  ... }@inputs: {
    darwinConfigurations = {
      "nick-macbook-small" = inputs.darwin.lib.darwinSystem {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          system = "aarch64-darwin";
          modules = [
            ./systems/darwin.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs = { 
                  inherit inputs; 
                  pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
                };
                users.nick.imports = [ ./homes/macs.nix ];
              };
            }
            /* home-manager.darwinModules.home-manager */
            /* { */
            /*   home-manager = { */
            /*     useGlobalPkgs = true; */
            /*     useUserPackages = true; */
            /*     /1* extraSpecialArgs = { inherit pwnvim; }; *1/ */
            /*     pkgs = nixpkgs.legacyPackages.aarch64-darwin; # Home-manager requires 'pkgs' instance *1/ */
            /*     extraSpecialArgs = { */ 
            /*       inherit inputs; */ 
            /*       pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin; */
            /*     }; # Pass flake inputs to our config */
            /*     users.nick.imports = [ */ 
            /*       ./systems/macs.nix */ 
            /*     ]; */
            /*   }; */
            /* } */
          ];
          /* modules = [ */
          /*   inputs.home-manager.darwinModules.home-manager */
          /*   /1* ./nix/modules/shared *1/ */
          /*   /1* sharedHostsConfig *1/ */
          /*   ./mods/darwin.nix */
          /* ]; */
        };
      };
    defaultPackage = {
      /* x86_64-darwin = home-manager.defaultPackage.x86_64-darwin; */
      aarch64-darwin = home-manager.defaultPackage.aarch64-darwin;
      /* aarch64-linux = home-manager.defaultPackage.aarch64-linux; */
    };
    /* homeConfigurations = { */
    /*   "nick@nick-macbook-small.local" = home-manager.lib.homeManagerConfiguration { */
    /*     pkgs = nixpkgs.legacyPackages.aarch64-darwin; # Home-manager requires 'pkgs' instance */
    /*     extraSpecialArgs = { */ 
    /*       inherit inputs; */ 
    /*       pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin; */
    /*     }; # Pass flake inputs to our config */
    /*     # > Our main home-manager configuration file < */
    /*     modules = [ */ 
    /*       # ./systems/darwin.nix */
    /*       ./systems/macs.nix */ 
    /*     ]; */
    /*   }; */    
    /* }; */
  };

}
    /* defaultPackage = { */
    /*   "x86_64-darwin" =  home-manager.defaultPackage.x86_64-darwin; */
    /*   "aarch64-darwin" = home-manager.defaultPackage.aarch64-darwin; */
    /* }; */
   /* darwinConfigurations."nick@nick-macbook-small.local" = darwin.lib.darwinSystem { */
   /*    system = "aarch64-darwin"; */
   /*    modules = [ ./mods/darwin.nix ]; */
   /*    specialArgs = { inherit home-manager; }; */
   /*  }; */
    /* darwinConfiguration."nick@nick-macbook-small.local" = darwin.lib.darwinSystem { */
    /*   system = "aarch64-darwin"; # "x86_64-darwin" if you're using a pre M1 mac */
    /*   pkgs = nixpkgs.legacyPackages.aarch64-darwin; # Home-manager requires 'pkgs' instance */
    /*   extraSpecialArgs = { */ 
    /*     inherit inputs; */ 
    /*     pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin; */
    /*   }; # Pass flake inputs to our config */
    /*   modules = [ */
    /*     home-manager.darwinModules.home-manager */
    /*     ./systems/macs.nix */ 
    /*   ]; # will be important later */
    /* }; */
    /* homeConfigurations."nick@MacBook-Pro.local" = home-manager.lib.homeManagerConfiguration { */
    /*     pkgs = nixpkgs.legacyPackages.aarch64-darwin; # Home-manager requires 'pkgs' instance */
    /*     extraSpecialArgs = { */ 
    /*       inherit inputs; */ 
    /*         pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin; */
    /*     }; # Pass flake inputs to our config */
    /*     # > Our main home-manager configuration file < */
    /*     modules = [ */ 
    /*       # ./systems/darwin.nix */
    /*       ./systems/macs.nix */ 
    /*       home-manager.darwinModules.home-manager */
    /*     ]; */
    /*   }; */    
    /* }; */
/* } */
