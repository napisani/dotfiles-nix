/**
 * Locates the interviews folder: golden/ (a clone of loancrate/filters-interview, the
 * starter) beside one clone per candidate, plus _reviews/ for output.
 *
 * Resolution, first match wins: an explicit path, $FILTERS_INTERVIEWS, then the current
 * directory or its parent when it holds golden/.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT_ENV = "FILTERS_INTERVIEWS";

/** Exit code for "this machine isn't set up yet"; the fix is in AGENTS.md. */
export const EXIT_SETUP = 5;

const AGENTS_MD = path.join(path.dirname(path.dirname(fileURLToPath(import.meta.url))), "AGENTS.md");
export const SETUP_HINT = `follow ${AGENTS_MD} to set this machine up`;

/** True when dir holds a golden/ checkout of the starter. */
export function hasGolden(dir) {
  return fs.existsSync(path.join(dir, "golden", "packages", "server", "borrowers.json"));
}

/** The interviews folder, or undefined when nothing points at one. */
export function findInterviewsRoot(explicit) {
  const configured = explicit ?? process.env[ROOT_ENV];
  if (configured) return path.resolve(configured);
  const cwd = process.cwd();
  return [cwd, path.dirname(cwd)].find(hasGolden);
}

/** golden/ beside the candidate's clone, else under $FILTERS_INTERVIEWS. */
export function findGolden(candidateDir) {
  const root = [path.dirname(candidateDir), process.env[ROOT_ENV]].filter(Boolean).find(hasGolden);
  return root && path.join(path.resolve(root), "golden");
}
