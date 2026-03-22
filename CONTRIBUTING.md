# Contributing to ObsidianReforged

Everyone is welcome — bug reports, pull requests, documentation, translations!

## Support

Open an issue on the [GitHub repository](https://github.com/jsoyer/ObsidianReforged).

## Reporting a bug

- Search existing issues first to avoid duplicates
- Include: exact error output, log files, server version, OS/architecture
- One bug per issue
- Describe expected vs. actual behavior and steps to reproduce

## Suggesting a feature

Open an issue describing the feature, why you want it, and how it should work.
If the idea is beyond the project scope, a fork may be the better path.

## Local development

### Requirements

- Docker with Buildx + QEMU for multi-arch builds:
  ```bash
  docker run --rm --privileged tonistiigi/binfmt --install all
  ```
- `shellcheck` — shell script linting
- `hadolint` — Dockerfile linting

### Quick local build

```bash
# Single-arch for local testing (fastest)
docker build -f Build.Dockerfile -t obsidian-reforged:dev .

# Run with a test volume
docker run -it --rm \
  -v minecraft-test:/minecraft \
  -p 25565:25565 -p 19132:19132/udp \
  -e Version=1.21.11 \
  obsidian-reforged:dev
```

### Iterating on start.sh

Bind-mount the script without rebuilding the image:

```bash
docker run -it --rm \
  -v minecraft-test:/minecraft \
  -v "$(pwd)/start.sh:/scripts/start.sh:ro" \
  obsidian-reforged:dev
```

### Multi-arch build (requires Docker Hub credentials)

```bash
./build.sh
```

### Linting (run before committing)

```bash
shellcheck start.sh
hadolint Build.Dockerfile
```

## Commit style

Conventional commits are required — the release workflow uses them to generate the changelog:

| Prefix | Use for |
|--------|---------|
| `feat:` | New capability |
| `fix:` | Bug fix |
| `refactor:` | Code change with no behaviour change |
| `docs:` | Documentation only |
| `chore:` | Maintenance, dependency bumps |
| `style:` | Formatting, no logic change |

Example: `fix: correct BedrockPort variable collision`

## Pull request process

1. Fork the repository and create a branch from `main`
2. Make your changes — one feature or bug fix per PR
3. Run `shellcheck` and `hadolint` locally
4. Open a PR against `main` — CI runs automatically (ShellCheck, Hadolint, yamllint)
5. A maintainer will review and merge

## Release process (maintainers)

1. Add a `## x.y.z - YYYY-MM-DD` block to `CHANGELOG.md`
2. Update `VERSION`
3. Commit: `git commit -m "chore: release vX.Y.Z"`
4. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`
5. The `build.yml` workflow builds and pushes the multi-arch image automatically
6. The `release.yml` workflow creates the GitHub Release with the changelog notes
