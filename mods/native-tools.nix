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
      # pi-subagents v0.70.1 is built and tested against this Pi SDK version.
      # Update the Pi SDK and the pinned pi-subagents ref together.
      "@earendil-works/pi-coding-agent" = "0.86.1";
      "@agentclientprotocol/claude-agent-acp" = "0.74.0";
      "@zed-industries/codex-acp" = "0.16.0";
      "@playwright/cli" = "0.1.19";
      "@napisani/scute" = "0.0.19";
    };
  };
  nativeTools.uv = {
    toolbox = "${config.home.homeDirectory}/toolbox";
  };
}
