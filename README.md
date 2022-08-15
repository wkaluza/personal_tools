# Personal tools

Please note:
This repository is public for my convenience.
Third party use is discouraged.
Contributions will be ignored.

## Development

### Linting and code style enforcement

To reformat and lint files in the repo:

```bash
$ bash ./script/lint_in_docker.bash
```

This has a dependency on `docker` and `jq`.
It builds a docker image that encapsulates all other dependencies.
It then runs the actual linter `./script/lint.bash` in a container.
