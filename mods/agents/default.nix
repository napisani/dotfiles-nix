# Shared agent choices. Host-specific overrides are explicit imports in homes/.
{
  config,
  pkgs-unstable,
  lib,
  ...
}:
{
  imports = [
    ../internal/agents
    ../internal/global-tools.nix
  ];

  home.sessionVariables = {
    PREFERRED_AGENT = "pi";
    REMOTE_PI_RELAY = "https://remote-pi.napisani.xyz";
  };

  agents = {
    enable = true;
    instructions = ../dotfiles/agents/AGENTS.md;
    rtkPackage = pkgs-unstable.rtk;

    skills = {
      shared = [
        # Pinned community skills.
        # anthropics/skills · author, eval, and iterate on skills
        "skill-creator"
        # anthropics/skills · co-write docs, specs, and proposals
        "doc-coauthoring"
        # anthropics/skills · visual direction for new or reshaped UI
        "frontend-design"
        # wshobson/agents · prompt patterns for LLM app code; LangChain/Python examples
        {
          name = "prompt-engineering-patterns";
          manualOnly = true;
        }
        # intellectronica/agent-skills · look up current library and framework docs
        "context7"
        # addyosmani/agent-skills · refactor for clarity without changing behavior
        "code-simplification"
        # johnpapa/ai-ready · generate AGENTS.md and per-tool agent config for a repo
        {
          name = "ai-ready";
          manualOnly = true;
        }
        # obra/superpowers · structured ideation before picking an approach
        {
          name = "brainstorming";
          manualOnly = true;
        }
        # obra/superpowers · hypothesis-driven debugging loop
        {
          name = "systematic-debugging";
          manualOnly = true;
        }
        # mattpocock/skills · diagnose hard bugs and performance regressions
        "diagnosing-bugs"
        # mattpocock/skills · resolve an in-progress merge or rebase conflict
        "resolving-merge-conflicts"
        # mattpocock/skills · compact this session into a handoff doc for a fresh agent
        "handoff"
        # mattpocock/skills · user entry point; its whole body calls grilling
        "grill-me"
        # mattpocock/skills · the interview itself; grill-me and grill-with-docs
        # call it, and a manualOnly skill cannot be reached by another skill
        "grilling"
        # mattpocock/skills · grilling plus ADR and glossary output
        "grill-with-docs"
        # mattpocock/skills · how to word skills, AGENTS.md, and agent-facing docs
        "writing-for-agents"
        # mattpocock/skills · generate a bash wizard for steps only a human can do
        {
          name = "wizard";
          manualOnly = true;
        }
        # mattpocock/skills · survey the codebase for deepening opportunities
        "improve-codebase-architecture"
        # mattpocock/skills · vocabulary for deep modules and where seams go
        "codebase-design"
        # mattpocock/skills · red-green-refactor through public interfaces
        "tdd"
        # mattpocock/skills · build the domain model, CONTEXT.md, and ADRs
        "domain-modeling"
        # mattpocock/skills · throwaway prototype to answer a design question
        {
          name = "prototype";
          manualOnly = true;
        }
        # cursor/plugins pstack · sketch types and module shape before writing code
        {
          name = "architect";
          manualOnly = true;
        }
        # cursor/plugins pstack · what a change could break beyond its own diff
        {
          name = "blast-radius";
          manualOnly = true;
        }
        # cursor/plugins pstack · subsystem walkthrough, placement and layering questions
        {
          name = "how";
          manualOnly = true;
        }
        # cursor/plugins pstack · how plus why, woven into one explanation
        {
          name = "teach";
          manualOnly = true;
        }
        # cursor/plugins pstack · generate a project-local skill that drives the real app
        {
          name = "create-verification-skill";
          manualOnly = true;
        }
        # cursor/plugins pstack · keep that verification skill honest as the app changes
        {
          name = "maintain-verification-skill";
          manualOnly = true;
        }
        # cursor/plugins pstack · design rationale from git, tickets, docs, and telemetry
        {
          name = "why";
          manualOnly = true;
        }
        # cursor/plugins pstack · run N candidates at one task, graft the best parts together
        {
          name = "arena";
          manualOnly = true;
        }
        # cursor/plugins pstack · TypeScript idioms when reading or editing .ts/.tsx
        "typescript-best-practices"
        # cursor/plugins pstack · strip AI tells from generated prose
        "unslop"
        # napisani/proctmux · write, fix, or explain a proctmux.yaml
        "proctmux-config"
        # pub/vantage-nvim · snapshot this session into .vantage/agent-context.md
        "vantage-distill-session"
        # pub/vantage-nvim · emit reviewable line pointers for the Neovim quickfix list
        "vantage-author-walkthrough"
        # pub/vantage-nvim · guided tour through a diff in Neovim
        "vantage-author-diff-tour"
        # microsoft/playwright-cli · drive a browser and work with Playwright tests
        "playwright-cli"
        # langchain-ai/deepagents · multi-source web research with cited findings
        "web-research"
        # softaworks/agent-toolkit · author Mermaid diagrams of any type
        "mermaid-diagrams"
        # raine/workmux · create and manage a worktree session
        {
          name = "workmux-worktree";
          manualOnly = true;
        }
        # raine/workmux · coordinate work across several worktree sessions
        {
          name = "workmux-coordinator";
          manualOnly = true;
        }
        # raine/workmux · merge a worktree session back
        {
          name = "workmux-merge";
          manualOnly = true;
        }
        # raine/workmux · rebase a worktree session
        {
          name = "workmux-rebase";
          manualOnly = true;
        }
        # raine/workmux · open a PR from a worktree session
        {
          name = "workmux-open-pr";
          manualOnly = true;
        }
        # raine/workmux · reference for the workmux CLI itself
        {
          name = "workmux-reference";
          manualOnly = true;
        }
        # petergyang/no-ai-slop · edit prose to read human while keeping the writer's voice
        {
          name = "no-ai-slop";
          manualOnly = true;
        }
        # humanlayer/skills · explain the current topic with diagrams and code sketches
        "show-me"
        # nicobailon/visual-explainer · self-contained HTML explainers for systems and plans
        "visual-explainer"
        # priv/skills · six-lens read-only review with adversarial verification
        {
          name = "multi-valued-review";
          manualOnly = true;
        }
        # priv/skills · triage an MVR report against the diff's own scope
        {
          name = "mvr-suggestions";
          manualOnly = true;
        }
        # priv/skills · manage project-local .nvim.lua settings
        {
          name = "neovim-project-config";
          manualOnly = true;
        }
        # patricio0312rev/skills · RFC for a proposal, with alternatives and rollout plan
        {
          name = "rfc-generator";
          manualOnly = true;
        }
        # sopaco/deepwiki-rs · generate architecture docs and C4 diagrams for a codebase
        {
          name = "smart-docs";
          manualOnly = true;
        }

        # Repo-local shared skills.
        # repo-local · triage PR review comments and draft replies
        "address-pr-feedback"
        # repo-local · add or change agent assets declaratively in this repo
        "agent-management"
        {
          name = "classify";
          manualOnly = true;
        }
        # repo-local · guided design session ending in a typed tech spec
        "forge-solution"
        # repo-local · read and write Obsidian vault notes
        "ob-note"
        # repo-local · rebase onto trunk or the stack parent, force-push with lease
        "rebase-from-parent"
        # repo-local · merge the parent in, preserving history
        "merge-parent-into-branch"
        # repo-local · resolve conflicts after a Stackman rebase stops
        "stackman-rebase-conflicts"
        # repo-local · write a typed call-stack architecture handoff
        "tech-spec"
      ];

    };

    providers.ollama = {
      baseUrl = lib.mkDefault "https://ollama.napisani.xyz/v1";
      models = lib.mkDefault [ ];
    };

    claude = {
      enable = true;
      rtk.enable = true;
      pluginMarketplaces = [ "nicobailon/visual-explainer" ];
      plugins = [ "visual-explainer@visual-explainer-marketplace" ];
      settings = {
        editorMode = "vim";
        permissions.defaultMode = "auto";
      };
    };

    codex = {
      enable = true;
      rtk.enable = true;
    };

    pi = {
      enable = true;
      rtk.enable = true;
      # claude-agent-sdk-pi remains intentionally absent: its stale pi-ai peer
      # range breaks dependency resolution for the other Pi extensions. See
      # WORKAROUNDS.md.
      settings = {
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-luna";
        defaultThinkingLevel = "high";
        transport = "sse";
        theme = "kanagawa-dragon";
        openaiReasoningMode.fast = false;
        # Use the same local Vantage checkout as Neovim, not a second copy of
        # its bridge implementation or a temporary feature worktree.
        extensions = [
          "${config.home.homeDirectory}/code/monorepo/pub/vantage-nvim/server/src/neovim/runtime/adjacent/extension.ts"
        ];
      };
      skillPaths = [ "~/code/*/apps/*/.agents/skills" ];
      # These packages provide native binaries or package-specific setup used by
      # the declared Pi extensions. Name-level approval intentionally follows
      # extension updates; adding a new script-owning dependency still produces
      # npm's review warning until it is added here.
      allowScripts = [
        "@google/genai"
        "@lincoln504/pi-research"
        "better-sqlite3"
        "esbuild"
        "koffi"
        "onnxruntime-node"
        "protobufjs"
        "sharp"
        "webgpu"
      ];
      # Keep this extension and the native Pi SDK in lockstep. The unqualified
      # git source previously advanced ahead of the pinned Pi installation.
      packages = [
        "npm:@ayulab/pi-rewind"
        "git:github.com/nicobailon/pi-subagents@v0.70.1"
        "npm:@datspike/pi-inline-slash-extension"
        "npm:@ff-labs/pi-fff"
        "npm:@juicesharp/rpiv-btw"
        "npm:@juicesharp/rpiv-ask-user-question"
        "npm:@lincoln504/pi-research"
        "npm:pi-vim"
        "npm:pi-web-access"
        "npm:remote-pi@0.7.0"
        # Routes Pi through the Claude Agent SDK without the stale pi-ai peer
        # range and removed getModels call in claude-agent-sdk-pi.
        "npm:pi-claude-bridge"
        "npm:pi-goal"
        "npm:pi-blackhole"
        # Direct dependency for local extensions; Pi's package root is not an
        # ancestor of individually linked extension files during Node resolution.
        "npm:@earendil-works/pi-tui@0.86.1"
        "git:github.com/nicobailon/visual-explainer"
      ];
    };

    opencode = {
      enable = true;
      rtk.enable = true;
      settings = builtins.fromJSON (builtins.readFile ../dotfiles/opencode-config.json);
    };
  };
}
