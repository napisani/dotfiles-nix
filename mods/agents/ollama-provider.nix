# agents/ollama-provider.nix — single source of truth for which ollama
# provider the agents (Pi's settings.json + OpenCode's config.json) register.
# Add or remove a model id here and both agents pick it up on the next
# rebuild.
#
# The Loancrate Mac runs its own local Ollama instance with a smaller model
# set; every other machine uses the shared remote provider below. This is the
# model list the agents' ollama provider offers (served by `baseUrl`); it is
# deliberately separate from mods/model-runtimes.nix's declaredModels, which
# manages the *local* runtime's model cache. A model must actually exist on
# the ollama server at `baseUrl` for the agents to use it.
{ isLoancrateMac }:
if isLoancrateMac then
  {
    baseUrl = "http://localhost:11434/v1";
    models = [
      "qwen3:1.7b"
      "qwen3.6-coding"
    ];
  }
else
  {
    baseUrl = "https://ollama.napisani.xyz/v1";
    models = [
      "qwen3:1.7b"
      "qwen3:0.6b"
    ];
  }
