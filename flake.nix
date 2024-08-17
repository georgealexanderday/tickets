{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule

      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.


        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        packages.default = pkgs.hello;


        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ beam.packages.erlang_27.elixir_1_17 mix2nix rabbitmq-server ];



          shellHook = ''
              # Set HOME explicitly
              export HOME=$HOME
  
              # Create directories
              mkdir -p $HOME/.rabbitmq/mnesia $HOME/.rabbitmq/log $HOME/.rabbitmq/config $HOME/.rabbitmq/bin

              # Export environment variables
              export RABBITMQ_CONFIG_FILE=$PWD/rabbitmq.conf
              export RABBITMQ_MNESIA_BASE=$HOME/.rabbitmq/mnesia
              export RABBITMQ_MNESIA_DIR=$HOME/.rabbitmq/mnesia
              export RABBITMQ_LOG_BASE=$HOME/.rabbitmq/log
              export RABBITMQ_LOGS=$HOME/.rabbitmq/log/rabbitmq.log
              export RABBITMQ_PID_FILE=$HOME/.rabbitmq/rabbitmq.pid
              export RABBITMQ_NODENAME=rabbit@localhost
              export RABBITMQ_NODE_IP_ADDRESS=127.0.0.1
              export RABBITMQ_ENABLED_PLUGINS_FILE=$HOME/.rabbitmq/config/enabled_plugins
              export PATH=$HOME/.rabbitmq/bin:$PATH

              # Ensure .erlang.cookie exists and has correct permissions
              touch $HOME/.erlang.cookie
              chmod 400 $HOME/.erlang.cookie

              # Create a default rabbitmq.conf if it doesn't exist
              if [ ! -f $PWD/rabbitmq.conf ]; then
                echo "Creating default rabbitmq.conf"
                cat << EOF > $PWD/rabbitmq.conf
            listeners.tcp.default = 5672
            management.tcp.port = 15672
            management.tcp.ip = 127.0.0.1
            loopback_users.guest = false
            EOF
              fi

              # Enable management plugin by default
              echo "[rabbitmq_management]." > $HOME/.rabbitmq/config/enabled_plugins

              # Create shell scripts for RabbitMQ management
              cat << 'EOF' > $HOME/.rabbitmq/bin/start_rabbitmq
            #!/bin/sh
            rabbitmq-server -detached
            echo "RabbitMQ started in detached mode. Enabling stable feature flags..."
            sleep 5  # Wait a bit for RabbitMQ to fully start
            rabbitmqctl enable_feature_flag all
            echo "Stable feature flags enabled."
            echo "Management interface available at http://localhost:15672"
            echo "Default username and password are both 'guest'"
            EOF

              cat << 'EOF' > $HOME/.rabbitmq/bin/stop_rabbitmq
            #!/bin/sh
            if rabbitmqctl status >/dev/null 2>&1; then
                rabbitmqctl stop
                echo "RabbitMQ stopped"
            else
                echo "RabbitMQ is not running"
            fi
            EOF

              cat << 'EOF' > $HOME/.rabbitmq/bin/restart_rabbitmq
            #!/bin/sh
            stop_rabbitmq
            start_rabbitmq
            EOF

              cat << 'EOF' > $HOME/.rabbitmq/bin/rabbitmq_status
            #!/bin/sh
            rabbitmqctl status
            EOF

              chmod +x $HOME/.rabbitmq/bin/*

              echo "RabbitMQ environment set up."
              echo "To start RabbitMQ in detached mode, run: start_rabbitmq"
              echo "To stop RabbitMQ, run: stop_rabbitmq"
              echo "To restart RabbitMQ, run: restart_rabbitmq"
              echo "To check RabbitMQ status, run: rabbitmq_status"
          '';




          exitHook = ''
            echo "Stopping RabbitMQ..."
            $HOME/.rabbitmq/bin/stop_rabbitmq
            echo "Exiting development environment."

          '';

        };


      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    };
}
