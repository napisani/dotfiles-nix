# agents/ollama-provider.nix — single source of truth for the ollama models
# registered with the agents (Pi's settings.json + OpenCode's config.json). Add
# or remove a model id here and both agents pick it up on the next rebuild.
#
# This is the model list the agents' *remote ollama provider* offers (served by
# `baseUrl`); it is deliberately separate from mods/model-runtimes.nix's
# declaredModels, which manages the *local* runtime's model cache. A model must
# actually exist on the ollama server at `baseUrl` for the agents to use it.
{
  baseUrl = "https://ollama.napisani.xyz/v1";
  models = [
    "qwen3:1.7b"
    "qwen3:0.6b"
  ];
}
