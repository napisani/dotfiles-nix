# npm and uv are peer native-tool domains, independent of agents.enable.
# Profiles select tools and machine policy; adapters own native realization.
{
  config,
  ...
}:
{
  imports = [
    ./internal/npm.nix
    ./internal/uv.nix
    ./internal/global-tools.nix
  ];

  nativeTools.npm = {
    tools = {
      "@ellery/terminal-mcp" = "0.5.1";
      "@earendil-works/pi-coding-agent" = "0.85.0";
      "@agentclientprotocol/claude-agent-acp" = "0.74.0";
      "@zed-industries/codex-acp" = "0.16.0";
      "@playwright/cli" = "0.1.19";
    };
  };
  nativeTools.uv = {
    toolbox = "${config.home.homeDirectory}/toolbox";
  };
}
