{
  inputs,
  self,
  ...
} @ part-inputs: {
  imports = [];

  perSystem = {
    self',
    pkgs,
    lib,
    system,
    inputs',
    ...
  }: let
    # the providers to be available for terraform
    # see "nixpkgs/pkgs/applications/networking/cluster/terraform-providers/providers.json"
    terraformPluginsPredicate = p: [
      # p.aws
      # p.kubernetes
      # p.nomad
      # p.null
      # p.local
      p.random
      # p.template
      # p.tls
      # p.tfe
      # p.vault
    ];
    terraform = pkgs.terraform.withPlugins terraformPluginsPredicate;

    # specify the directory names of configurations to make available
    terraformConfigurationNames = ["core"];

    terraformConfigurationBuilder = let
      reducer = l: r:
        {
          "${r}" = rec {
            # the path to the terraform configuration's nix file
            configurationPath = "${self}/terraform/configurations/${r}/terraform.nix";

            # a derivation containing the terraform configuration's JSON
            terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
              inherit system;
              modules = [
                configurationPath
              ];

              # support manually specifying null values. without this terranix will remove keys with a null value
              # strip_nulls = true;
            };
          };
        }
        // l;
    in
      builtins.foldl' reducer {} terraformConfigurationNames;

    # collect the configurations with underscores so they can be exposed as packages
    terraformConfigurationPackages = let
      reducer = l: r: l // {"terraformConfiguration_${r}" = terraformConfigurationBuilder.${r}.terraformConfiguration;};
    in
      builtins.foldl' reducer {} terraformConfigurationNames;

    # alias the terraform command to execute within the proper directory
    terraform-command = let
      jq = "${pkgs.jq}/bin/jq";
      terraform-cli = "${terraform}/bin/terraform";
    in
      pkgs.writeShellScriptBin "tnix" ''
        set -euo pipefail
        # accept the configuration name as the first argument
        # use it to add a -chdir=''${configurationPath} argument to the terraform command

        # get the configuration name
        configurationName="$1"
        shift

        # navigate to the top-level directory before executing the terraform command
        pushd $(git rev-parse --show-toplevel)

        # determine the path to the configuration
        configurationPath=$(cat ${self'.packages.terraformConfigurationMatrix}/terraform-configuration-matrix.json | ${jq} -r '.configurations[] | select(.name == "'$configurationName'" ) | .path')

        # create a symlink, config.tf.json to the configuration's path
        ln -sf "$configurationPath" ./terraform/configurations/$configurationName/generated_config.tf.json

        # execute the terraform command
        ${terraform-cli} -chdir=./terraform/configurations/$configurationName "$@"

        # remove the symlink
        rm ./terraform/configurations/$configurationName/generated_config.tf.json

        # return to the original directory
        popd
      '';

    # push the current configuration to terraform cloud
    # this is useful for doing API-driven terraform runs
    # https://developer.hashicorp.com/terraform/cloud-docs/run/api#pushing-a-new-configuration-version
    push-configuration = let
      jq = "${pkgs.jq}/bin/jq";
      curl = "${pkgs.curl}/bin/curl";
      terraform-cli = "${terraform}/bin/terraform";
    in
      pkgs.writeShellScriptBin "tfcloud-push" ''
        set -euo pipefail
        # accept the configuration name as the first argument
        # use it to add a -chdir=''${configurationPath} argument to the terraform command

        # get the configuration name
        configurationName="$1"
        shift

        # organization name (from env)
        : ''${TFE_ORG?"TF_ORG must be set"}
        # tfcloud token (from env)
        : ''${TFE_TOKEN?"TF_TOKEN must be set"}
        # tfcloud url (from env, defaults to app.terraform.io)
        : ''${TFE_URL:="app.terraform.io"}

        # navigate to the top-level directory before executing the terraform command
        pushd $(git rev-parse --show-toplevel)

        # determine the path to the configuration
        configurationPath=$(cat ${self'.packages.terraformConfigurationMatrix}/terraform-configuration-matrix.json | ${jq} -r '.configurations[] | select(.name == "'$configurationName'" ) | .path')

        # create a symlink, config.tf.json to the configuration's path
        ln -sf "$configurationPath" ./terraform/configurations/$configurationName/generated_config.tf.json

        # determine the active workspace
        workspace=$(${terraform-cli} -chdir=./terraform/configurations/$configurationName workspace show)

        # package the configuration's directory into a tarball
        file_name="./content-$(date +%s).tar.gz"
        tar -zcvf $file_name -C ./terraform/configurations/$configurationName .

        # lookup the workspace id
        workspace_id=($(curl \
          --header "Authorization: Bearer $TF_TOKEN" \
          --header "Content-Type: application/vnd.api+json" \
          https://$TFE_URL/api/v2/organizations/$TF_ORG/workspaces/''$workspace \
          | ${jq} -r '.data.id'))t

        # create a new configuration version
        echo '{"data":{"type":"configuration-versions"}}' > ./create_config_version.json
        upload_url=($(curl \
          --header "Authorization: Bearer $TF_TOKEN" \
          --header "Content-Type: application/vnd.api+json" \
          --request POST \
          --data @create_config_version.json \
          https://$TFE_URL/api/v2/workspaces/$workspace_id/configuration-versions \
          | ${jq} -r '.data.attributes."upload-url"'))

        # finally, upload the configuration content to the newly created configuration version
        curl \
          --header "Content-Type: application/octet-stream" \
          --request PUT \
          --data-binary @"$file_name" \
          $upload_url

        ### cleanup

        # remove the symlink
        rm ./terraform/configurations/$configurationName/generated_config.tf.json

        # return to the original directory
        popd
      '';
  in rec {
    devShells.default = pkgs.mkShell {
      buildInputs = [
        terraform
        terraform-command
        push-configuration
      ];
      inherit (self.checks.${system}.pre-commit-hooks) shellHook;
    };

    checks = {
      pre-commit-hooks = inputs.pre-commit-hooks.lib.${system}.run {
        src = ../.;
        hooks = {
          alejandra.enable = true;
          terraform-format.enable = true;
        };
      };
    };

    packages =
      {
        # expose the internal terraform package
        inherit terraform;

        # expose a package containing a JSON list of configuration names and their paths
        terraformConfigurationMatrix = let
          # { configurations = [ { name = "core"; path = "/nix/store/..."; } ]; }
          reducer = l: r:
            l
            // {
              configurations =
                l.configurations
                ++ [
                  {
                    name = r;
                    path = terraformConfigurationBuilder.${r}.terraformConfiguration;
                  }
                ];
            };
          configurationJSON = builtins.toJSON (builtins.foldl' reducer {configurations = [];} terraformConfigurationNames);
        in
          pkgs.stdenv.mkDerivation {
            name = "terraform-configuration-matrix";
            buildCommand = ''
              mkdir -p $out
              echo '${configurationJSON}' > $out/terraform-configuration-matrix.json
            '';
          };
      }
      // terraformConfigurationPackages;

    apps = let
      # shortcuts for running commands inside a writeShellScriptBin
      jq = "${pkgs.jq}/bin/jq";

      generate-matrix-names = pkgs.writeShellScriptBin "generate-terraform-matrix" ''
        # access the 'name' key of each configuration
        cat ${packages.terraformConfigurationMatrix}/terraform-configuration-matrix.json | ${jq} -r '.configurations' | ${jq} 'map(.name)'
      '';
    in {
      # output a the available terraform configurations
      generateTerraformMatrix = {
        type = "app";
        program = pkgs.lib.getExe generate-matrix-names;
      };

      # run a terraform command within one of the configurations
      tnix = {
        type = "app";
        program = pkgs.lib.getExe terraform-command;
      };
    };
  };
}
