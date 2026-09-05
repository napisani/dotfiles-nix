# Pure skill source catalog. This file answers only: given a skill name, where
# does its content come from? Selection, machine policy, manual-only intent,
# and home.file realization live elsewhere.
{ inputs }:
let
  pinned = source: path: {
    kind = "pinned";
    inherit source path;
  };
  local = path: {
    kind = "local";
    inherit path;
  };
in
{
  skill-creator = pinned inputs.anthropic-skills "skills/skill-creator";
  doc-coauthoring = pinned inputs.anthropic-skills "skills/doc-coauthoring";
  frontend-design = pinned inputs.anthropic-skills "skills/frontend-design";

  prompt-engineering-patterns = pinned inputs.wshobson-agents "plugins/llm-application-dev/skills/prompt-engineering-patterns";
  context7 = pinned inputs.intellectronica-agent-skills "skills/context7";
  code-simplification = pinned inputs.addyosmani-agent-skills "skills/code-simplification";

  brainstorming = pinned inputs.superpowers "skills/brainstorming";
  systematic-debugging = pinned inputs.superpowers "skills/systematic-debugging";

  diagnosing-bugs = pinned inputs.mattpocock-skills "skills/engineering/diagnosing-bugs";
  resolving-merge-conflicts = pinned inputs.mattpocock-skills "skills/engineering/resolving-merge-conflicts";
  handoff = pinned inputs.mattpocock-skills "skills/productivity/handoff";
  grill-me = pinned inputs.mattpocock-skills "skills/productivity/grill-me";
  grill-with-docs = pinned inputs.mattpocock-skills "skills/engineering/grill-with-docs";
  improve-codebase-architecture = pinned inputs.mattpocock-skills "skills/engineering/improve-codebase-architecture";
  codebase-design = pinned inputs.mattpocock-skills "skills/engineering/codebase-design";
  tdd = pinned inputs.mattpocock-skills "skills/engineering/tdd";
  implement = pinned inputs.mattpocock-skills "skills/engineering/implement";
  to-spec = pinned inputs.mattpocock-skills "skills/engineering/to-spec";
  domain-modeling = pinned inputs.mattpocock-skills "skills/engineering/domain-modeling";
  prototype = pinned inputs.mattpocock-skills "skills/engineering/prototype";

  proctmux-config = pinned inputs.proctmux "skills/proctmux-config";
  vantage-distill-session = pinned inputs.vantage-nvim-skills "skills/vantage-distill-session";
  vantage-author-walkthrough = pinned inputs.vantage-nvim-skills "skills/vantage-author-walkthrough";
  playwright-cli = pinned inputs.playwright-cli-skills "skills/playwright-cli";
  web-research = pinned inputs.deepagents "libs/code/examples/skills/web-research";
  mermaid-diagrams = pinned inputs.softaworks-agent-toolkit "dist/plugins/mermaid-diagrams/skills/mermaid-diagrams";
  worktree = pinned inputs.workmux-skills "skills/worktree";
  no-ai-slop = pinned inputs.no-ai-slop "skills/no-ai-slop";
  show-me = pinned inputs.humanlayer-skills "plugins/show-me/skills/show-me";
  visual-explainer = pinned inputs.builderio-skills "skills/visual-explainer";

  # This input is a working-tree path rooted at priv/skills, so these paths are
  # relative to that directory rather than the monorepo root.
  multi-valued-review = pinned inputs.private-skills "multi-valued-review";
  mvr-suggestions = pinned inputs.private-skills "mvr-suggestions";
  neovim-project-config = pinned inputs.private-skills "neovim-project-config";
  loancrate-with-workmux-stack-handoff = pinned inputs.private-skills "loancrate-with-workmux-stack-handoff";
  loancrate-standup-prep = pinned inputs.private-skills "loancrate-standup-prep";
  loancrate-analyze-agent-self-improve-trend = pinned inputs.private-skills "loancrate-analyze-agent-self-improve-trend";
  loancrate-weekly-update-draft = pinned inputs.private-skills "loancrate-weekly-update-draft";
  loancrate-weekly-project-update-draft = pinned inputs.private-skills "loancrate-weekly-project-update-draft";
  loancrate-slack-relay = pinned inputs.private-skills "loancrate-slack-relay";
  loancrate-pr-maintainer = pinned inputs.private-skills "loancrate-pr-maintainer";
  loancrate-prepare-perf-impact = pinned inputs.private-skills "loancrate-prepare-perf-impact";

  loancrate-lc-script = pinned inputs.lc-script-skills "skills/loancrate-lc-script";
  loancrate-eval-model-candidates-ci = pinned inputs.lc-script-skills "skills/loancrate-eval-model-candidates-ci";
  loancrate-ob-pricing-regression-test = pinned inputs.lc-script-skills "skills/loancrate-ob-pricing-regression-test";
  loancrate-run-local-agent-eval = pinned inputs.lc-script-skills "skills/loancrate-run-local-agent-eval";

  rfc-generator = pinned inputs.patricio0312rev-skills "architecture/rfc-generator";
  smart-docs = pinned inputs.deepwiki-rs-skills "skills/smart-docs";

  address-pr-feedback = local "agents/shared-skills/address-pr-feedback";
  agent-management = local "agents/shared-skills/agent-management";
  forge-solution = local "agents/shared-skills/forge-solution";
  ob-note = local "agents/shared-skills/ob-note";
  rebase-from-parent = local "agents/shared-skills/rebase-from-parent";
  stackman-rebase-conflicts = local "agents/shared-skills/stackman-rebase-conflicts";
  tech-spec = local "agents/shared-skills/tech-spec";
}
