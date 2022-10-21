{
  description = "stable-diffusion";

  inputs = {
    nixlib.url = "github:nix-community/nixpkgs.lib";
    nixpkgs.url = "github:colemickens/nixpkgs/stable-diff";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://stable-diff.cachix.org"
    ];
    extra-trusted-public-keys = [
      "stable-diff.cachix.org-1:liYFm3f3q1dAoilj2Ag2IEKzW3Q9/HJcLlrAIytAcy0="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    experimental-features = [ "nix-command" "flakes" "recursive-nix" ];
  };

  outputs = inputs:
    let
      nixlib = inputs.nixlib.outputs.lib;
      nixpkgs_ = forAllSystems (system: import inputs.nixpkgs { inherit system; });
      supportedSystems = [
        "x86_64-linux"
      ];
      forAllSystems = nixlib.genAttrs supportedSystems;
    in
    rec {
      apps = forAllSystems (system:
        let
          pkgs = import inputs.nixpkgs {
            config.allowUnfree = true;
            config.cudaSupport = true;
            system = system;
          };

          pyenv = pkgs.python3.withPackages (ps: [
            pkgs.cudatoolkit
            ps.python

            # From conda-forge
            ps.pytorch
            ps.torchvision
            ps.numpy

            # Pip
            ps.opencv4
            ps.pudb
            ps.imageio
            ps.imageio-ffmpeg
            ps.pytorch-lightning
            ps.omegaconf
            ps.test-tube
            ps.einops
            ps.transformers
            ps.torchmetrics
            ps.pynvml

            ps.loguru
            ps.numba
            ps.eventlet
            ps.flask
            ps.flask-socketio

            ps.idna
          ]);

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc
          ];
        in
        rec {
          default = {
            type = "app";
            program = (pkgs.writeShellScript "run-invoke-ai.sh" ''
              set -euo pipefail
            
              # TODO: need to pull the python packages into scope here
            
              export WEIGHTS_stable_diffusion_1_4="''${HF_SD_MODEL}"

              export PYTHONPATH=${pyenv}/${pyenv.sitePackages}
              export PATH=$PATH:${pyenv}:${pkgs.python3}/bin

              python3 -m venv venv
              . venv/bin/activate
      
              pip install \
                -e "git+https://github.com/CompVis/taming-transformers.git@master#egg=taming-transformers" \
                -e "git+https://github.com/crowsonkb/k-diffusion#egg=k_diffusion" \
                -e .

              python3 scripts/preload_models.py
              python3 scripts/invoke.py \
                --web \
                --host 0.0.0.0 \
                --port 7860
            '').outPath;
          };
        });
    };
}


