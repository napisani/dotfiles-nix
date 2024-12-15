import argparse
import os
from typing import List

import yaml
from aider.coders import Coder
from aider.models import Model


def load_config(config_file: str) -> dict:
    with open(config_file, "r") as f:
        if config_file.endswith(".json"):
            import json

            return json.load(f)
        elif config_file.endswith(".yaml") or config_file.endswith(".yml"):
            return yaml.safe_load(f)
        else:
            raise ValueError("Unsupported file format. Use .json, .yaml, or .yml")


def get_files_from_config(config: dict, key: str) -> List[str]:
    files = config.get(key, [])
    return [os.path.abspath(f) for f in files if os.path.exists(f)]


def main():
    parser = argparse.ArgumentParser(description="Apply prompts to files using Aider.")
    parser.add_argument(
        "config_file", help="Path to the configuration file (JSON or YAML)"
    )
    args = parser.parse_args()

    config = load_config(args.config_file)

    writable_files = get_files_from_config(config, "writable_files")
    readonly_files = get_files_from_config(config, "readonly_files")
    prompt = config.get("prompt", "")

    if not writable_files:
        print("Error: No writable files specified or found.")
        return

    model = Model("gpt-4")

    coder = Coder.create(
        auto_commits=False, main_model=model, fnames=writable_files + readonly_files
    )

    coder.run(prompt)
    print("Prompt applied. Please review the changes in the writable files.")


if __name__ == "__main__":
    main()
