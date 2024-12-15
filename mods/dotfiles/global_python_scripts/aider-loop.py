import os

from aider.coders import Coder
from aider.models import Model


def main():
    # This is a list of files to add to the chat

    d = "/Users/nick/code/kube-home-lab/src"
    # recursively get all ts files
    extras = [
        d + "/../tsconfig.json",
        d + "/../deno.json",
    ]

    ts_files = []
    for root, dirs, files in os.walk(d):
        for file in files:
            if file.endswith(".ts"):
                ts_files.append(os.path.join(root, file))
    print(ts_files)

    model = Model("gpt-4o")

    for ts_file in ts_files:
        # Create a coder object
        coder = Coder.create(
            auto_commits=False, main_model=model, fnames=[*extras, ts_file]
        )
        coder.run(
            "This project is a node js cdk8s project. Please convert this typescript module to use Deno instead of Node. Also rewrite any imports to avoid using any typscript aliases. Just use relative imports instead."
        )
        input("Press Enter to continue...")

        # This will execute one instruction on those files and then return


if __name__ == "__main__":
    main()
