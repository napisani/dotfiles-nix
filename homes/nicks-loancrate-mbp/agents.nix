{ config, lib, ... }:
{
  agents = {
    providers.ollama = {
      baseUrl = "http://localhost:11434/v1";
      models = [
        "qwen3:1.7b"
        "qwen3.6-coding"
      ];
    };

    skills = {
      shared = [
        "loancrate-with-workmux-stack-handoff"
        "loancrate-standup-prep"
        "loancrate-analyze-agent-self-improve-trend"
        "loancrate-weekly-update-draft"
        "loancrate-weekly-project-update-draft"
        "loancrate-slack-relay"
        {
          name = "loancrate-pr-maintainer";
          manualOnly = true;
        }
        {
          name = "loancrate-prepare-perf-impact";
          manualOnly = true;
        }
        "loancrate-lc-script"
        "loancrate-eval-model-candidates-ci"
        "loancrate-ob-pricing-regression-test"
        "loancrate-run-local-agent-eval"
      ];
    };

    claude = {
      mcpServers = {
        linear = {
          type = "http";
          url = "https://mcp.linear.app/mcp";
        };
        figma = {
          type = "http";
          url = "https://mcp.figma.com/mcp";
        };
        bde = {
          type = "http";
          url = "https://bde.dsci.loancrate.dev/mcp";
        };
      };
      pluginMarketplaces = lib.mkAfter [ "loancrate/org-claude-skills#workmux" ];
      plugins = lib.mkAfter [
        "lc@lc"
        "code@lc"
      ];
      loancrateConfig = {
        user_prefix = "nick";
        work_root = "${config.home.homeDirectory}/Work";
        team_repos.lc = "${config.home.homeDirectory}/code/loancrate/loancrate";
      };
    };

    codex.mcpServers = {
      linear.url = "https://mcp.linear.app/mcp";
      figma.url = "https://mcp.figma.com/mcp";
      bde.url = "https://bde.dsci.loancrate.dev/mcp";
    };

    pi.mcpServers = {
      linear = {
        url = "https://mcp.linear.app/mcp";
        lifecycle = "lazy";
      };
      figma = {
        url = "https://mcp.figma.com/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
          scope = "mcp:connect";
        };
        lifecycle = "lazy";
      };
      bde = {
        url = "https://bde.dsci.loancrate.dev/mcp";
        lifecycle = "lazy";
      };
      datadog = {
        url = "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
      gmail = {
        url = "https://gmailmcp.googleapis.com/mcp/v1";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
      notion = {
        url = "https://mcp.notion.com/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
      sentry = {
        url = "https://mcp.sentry.dev/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
    };

    opencode.mcpServers = {
      linear = {
        type = "remote";
        url = "https://mcp.linear.app/mcp";
      };
      figma = {
        type = "remote";
        url = "https://mcp.figma.com/mcp";
      };
      bde = {
        type = "remote";
        url = "https://bde.dsci.loancrate.dev/mcp";
      };
    };
  };
}
