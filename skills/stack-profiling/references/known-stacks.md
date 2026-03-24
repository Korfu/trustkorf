# Known Stack Detection Patterns

## Signal File Matrix

| Signal File | Language | Test Runner | Type Check | Linter | Build |
|---|---|---|---|---|---|
| `package.json` | JavaScript/TypeScript | jest, vitest, mocha (check devDependencies + scripts) | tsc (if tsconfig.json exists) | eslint (check devDependencies) | npm/yarn/pnpm run build |
| `tsconfig.json` | TypeScript | (from package.json) | `npx tsc --noEmit` | eslint | `npx tsc` |
| `pyproject.toml` | Python | pytest | mypy, pyright (check [tool.*] sections) | ruff, flake8 (check [tool.*]) | - |
| `setup.py` / `setup.cfg` | Python | pytest, unittest | mypy | flake8 | - |
| `requirements.txt` | Python | pytest (if listed) | mypy (if listed) | flake8/ruff (if listed) | - |
| `go.mod` | Go | `go test ./...` | `go vet ./...` | golangci-lint (if installed) | `go build ./...` |
| `Cargo.toml` | Rust | `cargo test` | (built into compiler) | `cargo clippy` | `cargo build` |
| `pom.xml` | Java (Maven) | `mvn test` | (javac, built-in) | checkstyle, spotbugs | `mvn package` |
| `build.gradle` / `build.gradle.kts` | Java/Kotlin (Gradle) | `./gradlew test` | (built-in) | spotless, checkstyle | `./gradlew build` |
| `Gemfile` | Ruby | rspec, minitest (check Gemfile) | sorbet (if present) | rubocop (if present) | - |
| `*.csproj` / `*.sln` | C# | `dotnet test` | (built into compiler) | `dotnet format --verify-no-changes` | `dotnet build` |
| `*.fsproj` | F# | `dotnet test` | (built into compiler) | `dotnet format --verify-no-changes` | `dotnet build` |
| `composer.json` | PHP | phpunit (check require-dev) | phpstan (if present) | php-cs-fixer (if present) | - |
| `mix.exs` | Elixir | `mix test` | dialyxir (if present) | `mix credo` (if present) | `mix compile` |
| `deno.json` / `deno.jsonc` | Deno/TypeScript | `deno test` | (built-in) | `deno lint` | - |
| `bun.lockb` | Bun/TypeScript | `bun test` | tsc (if tsconfig.json) | eslint | `bun run build` |

## Framework Detection

| Framework File | Framework | Additional Commands |
|---|---|---|
| `next.config.js` / `next.config.mjs` / `next.config.ts` | Next.js | `next build`, `next lint` |
| `angular.json` | Angular | `ng test`, `ng build`, `ng lint` |
| `vue.config.js` / `vite.config.ts` (with vue plugin) | Vue | (from package.json scripts) |
| `svelte.config.js` | SvelteKit | (from package.json scripts) |
| `remix.config.js` | Remix | (from package.json scripts) |
| `astro.config.mjs` | Astro | (from package.json scripts) |
| `manage.py` | Django | `python manage.py test` |
| `config/routes.rb` | Rails | `bundle exec rspec` or `rails test` |
| `Program.cs` + `*.csproj` with `Microsoft.AspNetCore` | ASP.NET Core | `dotnet test`, `dotnet build` |
| `Startup.cs` or `Program.cs` with WebApplication | ASP.NET Core | `dotnet test`, `dotnet build` |
| `nest-cli.json` or `@nestjs/core` in package.json | NestJS | `nest build`, `nest test` (usually jest) |

## E2E Framework Detection

| Config File | Framework | Command |
|---|---|---|
| `playwright.config.ts` / `playwright.config.js` | Playwright | `npx playwright test` |
| `cypress.config.ts` / `cypress.config.js` | Cypress | `npx cypress run` |
| `cypress/` directory | Cypress (legacy) | `npx cypress run` |
| `e2e/` with playwright dependency | Playwright | `npx playwright test` |
| `*.spec.ts` with Playwright imports | Playwright | `npx playwright test` |

## Test Runner Config Files

These config files control which test files the runner discovers. If the config restricts scope (via `include`, `testMatch`, `testpaths`, etc.), tests outside that scope are silently skipped.

| Runner | Config Files | Scope-Controlling Keys |
|---|---|---|
| vitest | `vitest.config.{ts,js,mjs,mts}`, `vite.config.*` | `test.include`, `test.exclude`, `test.dir` |
| jest | `jest.config.{ts,js,mjs,cjs}`, `package.json:jest` | `testMatch`, `testPathPattern`, `roots`, `testPathIgnorePatterns` |
| pytest | `pyproject.toml:[tool.pytest.ini_options]`, `pytest.ini`, `setup.cfg`, `tox.ini` | `testpaths`, `python_files`, `python_classes`, `python_functions` |
| go test | N/A (package paths in command) | Package path argument (e.g., `./...` vs `./pkg/...`) |
| dotnet test | `*.sln`, `*.csproj`, `.runsettings` | Solution file determines which test projects run; `.runsettings` controls filters |
| rspec | `.rspec`, `spec/spec_helper.rb` | `--pattern`, `--default-path` |
| cargo test | `Cargo.toml` | `[[test]]` sections, `#[cfg(test)]` modules |
| mocha | `.mocharc.{yml,json,js}` | `spec`, `recursive`, `ignore` |
| ava | `ava.config.{js,cjs,mjs}`, `package.json:ava` | `files`, `ignoredByWatcher` |

## CI Configuration Detection

When signal files don't reveal the full picture, check CI configs:

| File | What to Look For |
|---|---|
| `.github/workflows/*.yml` | `run:` steps with test/lint/build commands |
| `Makefile` | Targets like `test`, `lint`, `build`, `check` |
| `Dockerfile` | `RUN` commands for tests/builds |
| `.gitlab-ci.yml` | `script:` entries |
| `Jenkinsfile` | `sh` steps |
| `azure-pipelines.yml` | `script:` entries |
| `operations/*.yml`, `pipelines/*.yml` | Azure DevOps pipelines in subdirectories (common in .NET projects) |
| `bitbucket-pipelines.yml` | `script:` entries |
| `.circleci/config.yml` | `run:` steps |

## Package Manager Detection

| Signal | Package Manager |
|---|---|
| `package-lock.json` | npm |
| `yarn.lock` | yarn |
| `pnpm-lock.yaml` | pnpm |
| `bun.lockb` | bun |
| `Pipfile.lock` | pipenv |
| `Pipfile` (without lock) | pipenv |
| `uv.lock` | uv |
| `poetry.lock` | poetry |
| `Cargo.lock` | cargo |
| `go.sum` | go modules |
| `packages.lock.json` (NuGet) | dotnet |
| `*.sln` | dotnet |
| `Gemfile.lock` | bundler |
| `composer.lock` | composer |
