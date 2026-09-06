# Shared model choices. Host-specific models and parameters belong in homes/.
{ lib, ... }:
{
  imports = [ ./internal/model-runtimes.nix ];

  modelRuntimes.declaredModels.ollama = lib.mkDefault [ "qwen3:1.7b" ];
}
