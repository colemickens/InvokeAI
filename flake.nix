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

      pkgs = import nixpkgs {
        config.allowUnfree = true;
        system = system;
        overlays = [
          (final: prev: {
            # TODO: I think there's another way to get CUDA now
            python3 = prev.python3.override {
              packageOverrides = python-self: python-super: {
                pytorch = python-super.pytorch.override { cudaSupport = true; };
              };
            };
          })
        ];
      };

      python = pkgs.python3;
      ps = python.pkgs;
      shell = pkgs.mkShell
        {
          packages = [
            pkgs.cudatoolkit
            python

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
          ];

          LD_LIBRARY_PATH = lib.makeLibraryPath [
            pkgs.stdenv.cc.cc
          ];

          shellHook = ''
            python3 -m venv venv
            . venv/bin/activate

            pip install \
              -e "git+https://github.com/CompVis/taming-transformers.git@master#egg=taming-transformers" \
              -e "git+https://github.com/crowsonkb/k-diffusion#egg=k_diffusion" \
              -e .
          '';
          # "albumentations==0.4.3" \
          # "torch-fidelity==0.3.0" \
          # "kornia==0.6" \
          # "imwatermark" \
          # "diffusers" \
        };
    in
    rec {
      apps = forAllSystems (system: rec {
        default = {
          type = "app";
          program = pkgs.writeShellScriptBin "run-invoke-ai.sh" ''
            set -euo pipefail
            
            # TODO: need to pull the python packages into scope here
            
            export WEIGHTS_stable-diffusion-1_4="${HF_SD_MODEL}"
            
            ${customPython} scripts/preload_models.py
            ${customPython} scripts/invoke.py \
              --web \
              --host 0.0.0.0 \
              --port 7860
          '';
        };
      });
    };
}


