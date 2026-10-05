# Pure skill source catalog. This file answers only: given a skill name, where
# does its content come from? Selection, machine policy, manual-only intent,
# and home.file realization live elsewhere.
{ inputs }:
let
  # `input` names the flake input so other tools can find its pinned commit in
  # flake.lock without fetching it.
  pinned = input: path: {
    kind = "pinned";
    source = inputs.${input};
    inherit input path;
  };
  pinnedRewritten = input: path: replacements: {
    kind = "pinned";
    source = inputs.${input};
    inherit input path replacements;
  };
  rewrite = from: to: { inherit from to; };
  local = path: {
    kind = "local";
    inherit path;
  };
in
{
  skill-creator = pinned "anthropic-skills" "skills/skill-creator";
  doc-coauthoring = pinned "anthropic-skills" "skills/doc-coauthoring";
  frontend-design = pinned "anthropic-skills" "skills/frontend-design";

  prompt-engineering-patterns = pinned "wshobson-agents" "plugins/llm-application-dev/skills/prompt-engineering-patterns";
  context7 = pinned "intellectronica-agent-skills" "skills/context7";
  code-simplification = pinned "addyosmani-agent-skills" "skills/code-simplification";
  ai-ready = pinned "ai-ready-skills" "skills/ai-ready";

  brainstorming = pinned "superpowers" "skills/brainstorming";
  systematic-debugging = pinned "superpowers" "skills/systematic-debugging";

  diagnosing-bugs = pinned "mattpocock-skills" "skills/engineering/diagnosing-bugs";
  resolving-merge-conflicts = pinned "mattpocock-skills" "skills/engineering/resolving-merge-conflicts";
  handoff = pinned "mattpocock-skills" "skills/productivity/handoff";
  grill-me = pinned "mattpocock-skills" "skills/productivity/grill-me";
  grilling = pinned "mattpocock-skills" "skills/productivity/grilling";
  grill-with-docs = pinned "mattpocock-skills" "skills/engineering/grill-with-docs";
  improve-codebase-architecture = pinned "mattpocock-skills" "skills/engineering/improve-codebase-architecture";
  codebase-design = pinned "mattpocock-skills" "skills/engineering/codebase-design";
  tdd = pinned "mattpocock-skills" "skills/engineering/tdd";
  writing-for-agents = pinned "mattpocock-skills" "skills/productivity/writing-for-agents";
  wizard = pinned "mattpocock-skills" "skills/engineering/wizard";
  domain-modeling = pinned "mattpocock-skills" "skills/engineering/domain-modeling";
  prototype = pinned "mattpocock-skills" "skills/engineering/prototype";

  architect = pinned "pstack" "pstack/skills/architect";
  blast-radius = pinned "pstack" "pstack/skills/blast-radius";
  how = pinned "pstack" "pstack/skills/how";
  teach = pinned "pstack" "pstack/skills/teach";
  create-verification-skill = pinned "pstack" "pstack/skills/create-verification-skill";
  maintain-verification-skill = pinned "pstack" "pstack/skills/maintain-verification-skill";
  why = pinned "pstack" "pstack/skills/why";
  arena = pinned "pstack" "pstack/skills/arena";
  # Both ship `disable-model-invocation: true` upstream. The module only ever
  # adds that key for manualOnly and never strips it, so without this rewrite a
  # non-manualOnly selection in default.nix cannot make them model-invocable.
  typescript-best-practices =
    pinnedRewritten "pstack" "pstack/skills/typescript-best-practices"
      [
        (rewrite "\ndisable-model-invocation: true\n" "\n")
      ];
  unslop = pinnedRewritten "pstack" "pstack/skills/unslop" [
    (rewrite "\ndisable-model-invocation: true\n" "\n")
  ];

  proctmux-config = pinned "proctmux" "skills/proctmux-config";
  mushy-lint-rule-config = pinned "mushy_lint" ".agents/skills/mushy-lint-rule-config";
  mushy-lint-run-review = pinned "mushy_lint" ".agents/skills/mushy-lint-run-review";
  vantage-distill-session = pinned "vantage-nvim-skills" "skills/vantage-distill-session";
  vantage-author-walkthrough = pinned "vantage-nvim-skills" "skills/vantage-author-walkthrough";
  vantage-author-diff-tour = pinned "vantage-nvim-skills" "skills/vantage-author-diff-tour";
  playwright-cli = pinned "playwright-cli-skills" "skills/playwright-cli";
  web-research = pinned "deepagents" "libs/code/examples/skills/web-research";
  mermaid-diagrams = pinned "softaworks-agent-toolkit" "dist/plugins/mermaid-diagrams/skills/mermaid-diagrams";

  # Keep Workmux's generic upstream names out of the shared skill namespace.
  # Internal slash references are rewritten with the frontmatter name so the
  # six skills continue to delegate to one another after namespacing.
  workmux-worktree = pinnedRewritten "workmux-skills" "skills/worktree" [
    (rewrite "name: worktree" "name: workmux-worktree")
    (rewrite "/worktree" "/workmux-worktree")
    (rewrite "/merge" "/workmux-merge")
  ];
  workmux-coordinator = pinnedRewritten "workmux-skills" "skills/coordinator" [
    (rewrite "name: coordinator" "name: workmux-coordinator")
    (rewrite "/merge" "/workmux-merge")
  ];
  workmux-merge = pinnedRewritten "workmux-skills" "skills/merge" [
    (rewrite "name: merge" "name: workmux-merge")
  ];
  workmux-rebase = pinnedRewritten "workmux-skills" "skills/rebase" [
    (rewrite "name: rebase" "name: workmux-rebase")
  ];
  workmux-open-pr = pinnedRewritten "workmux-skills" "skills/open-pr" [
    (rewrite "name: open-pr" "name: workmux-open-pr")
  ];
  workmux-reference = pinnedRewritten "workmux-skills" "skills/workmux" [
    (rewrite "name: workmux" "name: workmux-reference")
    (rewrite "\"/workmux add ...\"" "\"/workmux-reference add ...\"")
    (rewrite "/worktree" "/workmux-worktree")
    (rewrite "/coordinator" "/workmux-coordinator")
    (rewrite "/merge" "/workmux-merge")
    (rewrite "/rebase" "/workmux-rebase")
    (rewrite "/open-pr" "/workmux-open-pr")
  ];

  no-ai-slop = pinned "no-ai-slop" "skills/no-ai-slop";
  show-me = pinned "humanlayer-skills" "plugins/show-me/skills/show-me";
  visual-explainer = pinned "builderio-skills" "plugins/visual-explainer";

  # This input is a working-tree path rooted at priv/skills, so these paths are
  # relative to that directory rather than the monorepo root.
  multi-valued-review = pinned "private-skills" "multi-valued-review";
  mvr-suggestions = pinned "private-skills" "mvr-suggestions";
  neovim-project-config = pinned "private-skills" "neovim-project-config";
  loancrate-with-workmux-stack-handoff = pinned "private-skills" "loancrate-with-workmux-stack-handoff";
  loancrate-standup-prep = pinned "private-skills" "loancrate-standup-prep";
  loancrate-analyze-agent-self-improve-trend = pinned "private-skills" "loancrate-analyze-agent-self-improve-trend";
  loancrate-weekly-update-draft = pinned "private-skills" "loancrate-weekly-update-draft";
  loancrate-weekly-project-update-draft = pinned "private-skills" "loancrate-weekly-project-update-draft";
  loancrate-project-prioritization = pinned "private-skills" "loancrate-project-prioritization";
  loancrate-pr-maintainer = pinned "private-skills" "loancrate-pr-maintainer";
  loancrate-babysit-pr = pinned "private-skills" "loancrate-babysit-pr";
  loancrate-babysit-pr-stop = pinned "private-skills" "loancrate-babysit-pr-stop";
  loancrate-create-pr = pinned "private-skills" "loancrate-create-pr";
  loancrate-prepare-perf-impact = pinned "private-skills" "loancrate-prepare-perf-impact";
  loancrate-refresh-perf-scoreboard = pinned "private-skills" "loancrate-refresh-perf-scoreboard";

  loancrate-lc-script = pinned "lc-script-skills" "skills/loancrate-lc-script";
  loancrate-eval-model-candidates-ci = pinned "lc-script-skills" "skills/loancrate-eval-model-candidates-ci";
  loancrate-ob-pricing-regression-test = pinned "lc-script-skills" "skills/loancrate-ob-pricing-regression-test";
  loancrate-run-local-agent-eval = pinned "lc-script-skills" "skills/loancrate-run-local-agent-eval";
  loancrate-download-documents = pinned "lc-script-skills" "skills/loancrate-download-documents";

  rfc-generator = pinned "patricio0312rev-skills" "architecture/rfc-generator";
  smart-docs = pinned "deepwiki-rs-skills" "skills/smart-docs";

  address-pr-feedback = local "agents/shared-skills/address-pr-feedback";
  agent-management = local "agents/shared-skills/agent-management";
  classify = local "agents/shared-skills/classify";
  forge-solution = local "agents/shared-skills/forge-solution";
  ob-note = local "agents/shared-skills/ob-note";
  rebase-from-parent = local "agents/shared-skills/rebase-from-parent";
  merge-parent-into-branch = local "agents/shared-skills/merge-parent-into-branch";
  stackman-rebase-conflicts = local "agents/shared-skills/stackman-rebase-conflicts";
  tech-spec = local "agents/shared-skills/tech-spec";
}
