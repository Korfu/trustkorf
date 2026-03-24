#!/bin/bash
set -euo pipefail

# trustKORF Stack Detection Script
# Deterministic detection of project tech stack from signal files.
# Outputs JSON to stdout. Uses $CLAUDE_PROJECT_DIR or current directory.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

language="unknown"
framework="none"
testCommand="none"
testConfigFile="none"
typeCheckCommand="none"
lintCommand="none"
buildCommand="none"
e2eCommand="none"
e2eFramework="none"
packageManager="none"

# --- Language & Tool Detection ---

# C# / .NET
if ls "$PROJECT_DIR"/*.sln 2>/dev/null 1>&2 || ls "$PROJECT_DIR"/*.csproj 2>/dev/null 1>&2 || find "$PROJECT_DIR" -maxdepth 3 -name "*.csproj" -print -quit 2>/dev/null | grep -q .; then
  language="csharp"
  testCommand="dotnet test"
  typeCheckCommand="none"
  lintCommand="dotnet format --verify-no-changes"
  buildCommand="dotnet build"
  packageManager="dotnet"
fi

# TypeScript / JavaScript (Node.js)
if [ -f "$PROJECT_DIR/package.json" ]; then
  if [ "$language" = "unknown" ]; then
    if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
      language="typescript"
      typeCheckCommand="npx tsc --noEmit"
    else
      language="javascript"
    fi
  fi

  # Detect test runner from package.json
  if command -v jq &>/dev/null && [ -f "$PROJECT_DIR/package.json" ]; then
    scripts=$(jq -r '.scripts // {} | keys[]' "$PROJECT_DIR/package.json" 2>/dev/null || echo "")
    devDeps=$(jq -r '.devDependencies // {} | keys[]' "$PROJECT_DIR/package.json" 2>/dev/null || echo "")
    deps=$(jq -r '.dependencies // {} | keys[]' "$PROJECT_DIR/package.json" 2>/dev/null || echo "")

    # Test command
    if echo "$scripts" | grep -qw "test"; then
      testCommand="npm test"
    fi

    # Lint command
    if echo "$scripts" | grep -qw "lint"; then
      lintCommand="npm run lint"
    fi

    # Build command
    if echo "$scripts" | grep -qw "build"; then
      buildCommand="npm run build"
    fi
  fi

  # Package manager
  if [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
    packageManager="pnpm"
  elif [ -f "$PROJECT_DIR/yarn.lock" ]; then
    packageManager="yarn"
  elif [ -f "$PROJECT_DIR/bun.lockb" ]; then
    packageManager="bun"
  elif [ -f "$PROJECT_DIR/package-lock.json" ]; then
    packageManager="npm"
  fi
fi

# Python
if [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ] || [ -f "$PROJECT_DIR/requirements.txt" ]; then
  if [ "$language" = "unknown" ]; then
    language="python"
    testCommand="pytest"
    packageManager="pip"

    if [ -f "$PROJECT_DIR/poetry.lock" ]; then
      packageManager="poetry"
    elif [ -f "$PROJECT_DIR/Pipfile.lock" ]; then
      packageManager="pipenv"
    fi
  fi
fi

# Go
if [ -f "$PROJECT_DIR/go.mod" ]; then
  if [ "$language" = "unknown" ]; then
    language="go"
    testCommand="go test ./..."
    typeCheckCommand="go vet ./..."
    buildCommand="go build ./..."
    packageManager="go"

    if command -v golangci-lint &>/dev/null; then
      lintCommand="golangci-lint run"
    fi
  fi
fi

# Rust
if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  if [ "$language" = "unknown" ]; then
    language="rust"
    testCommand="cargo test"
    lintCommand="cargo clippy"
    buildCommand="cargo build"
    packageManager="cargo"
  fi
fi

# Java (Maven)
if [ -f "$PROJECT_DIR/pom.xml" ]; then
  if [ "$language" = "unknown" ]; then
    language="java"
    testCommand="mvn test"
    buildCommand="mvn package"
    packageManager="maven"
  fi
fi

# Java/Kotlin (Gradle)
if [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
  if [ "$language" = "unknown" ]; then
    language="java"
    testCommand="./gradlew test"
    buildCommand="./gradlew build"
    packageManager="gradle"
  fi
fi

# Ruby
if [ -f "$PROJECT_DIR/Gemfile" ]; then
  if [ "$language" = "unknown" ]; then
    language="ruby"
    testCommand="bundle exec rspec"
    packageManager="bundler"

    if grep -q "rubocop" "$PROJECT_DIR/Gemfile" 2>/dev/null; then
      lintCommand="bundle exec rubocop"
    fi
  fi
fi

# PHP
if [ -f "$PROJECT_DIR/composer.json" ]; then
  if [ "$language" = "unknown" ]; then
    language="php"
    testCommand="./vendor/bin/phpunit"
    packageManager="composer"
  fi
fi

# Elixir
if [ -f "$PROJECT_DIR/mix.exs" ]; then
  if [ "$language" = "unknown" ]; then
    language="elixir"
    testCommand="mix test"
    buildCommand="mix compile"
    packageManager="mix"
  fi
fi

# --- Framework Detection ---

if [ -f "$PROJECT_DIR/next.config.js" ] || [ -f "$PROJECT_DIR/next.config.mjs" ] || [ -f "$PROJECT_DIR/next.config.ts" ]; then
  framework="nextjs"
fi

if [ -f "$PROJECT_DIR/angular.json" ]; then
  framework="angular"
  testCommand="npx ng test --watch=false"
  buildCommand="npx ng build"
  lintCommand="npx ng lint"
fi

if [ -f "$PROJECT_DIR/svelte.config.js" ]; then
  framework="sveltekit"
fi

if [ -f "$PROJECT_DIR/manage.py" ]; then
  framework="django"
  testCommand="python manage.py test"
fi

if [ -f "$PROJECT_DIR/config/routes.rb" ]; then
  framework="rails"
fi

# ASP.NET Core detection
if [ "$language" = "csharp" ]; then
  if find "$PROJECT_DIR" -maxdepth 3 -name "*.csproj" -exec grep -l "Microsoft.AspNetCore" {} + 2>/dev/null | grep -q .; then
    framework="aspnet-core"
  fi
fi

# --- Test Runner Config Detection ---
# Find the config file that controls test scope (include/exclude patterns).
# This is critical — the test command may work, but the runner config
# may restrict which files it picks up.

for cfg in \
  vitest.config.ts vitest.config.js vitest.config.mjs vitest.config.mts \
  jest.config.ts jest.config.js jest.config.mjs jest.config.cjs \
  .jest.config.js .jest.config.ts \
  ava.config.js ava.config.cjs ava.config.mjs \
  .mocharc.yml .mocharc.json .mocharc.js \
  pytest.ini setup.cfg \
  .rspec; do
  if [ -f "$PROJECT_DIR/$cfg" ]; then
    testConfigFile="$cfg"
    break
  fi
done

# Check for inline config in package.json (jest or vitest key)
if [ "$testConfigFile" = "none" ] && [ -f "$PROJECT_DIR/package.json" ] && command -v jq &>/dev/null; then
  if jq -e '.jest' "$PROJECT_DIR/package.json" &>/dev/null; then
    testConfigFile="package.json:jest"
  fi
fi

# Check for pytest config in pyproject.toml
if [ "$testConfigFile" = "none" ] && [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  if grep -q '\[tool\.pytest' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    testConfigFile="pyproject.toml:tool.pytest"
  fi
fi

# Check for test config in Cargo.toml
if [ "$testConfigFile" = "none" ] && [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  if grep -q '\[\[test\]\]' "$PROJECT_DIR/Cargo.toml" 2>/dev/null; then
    testConfigFile="Cargo.toml:test"
  fi
fi

# --- E2E Detection ---

if [ -f "$PROJECT_DIR/playwright.config.ts" ] || [ -f "$PROJECT_DIR/playwright.config.js" ]; then
  e2eCommand="npx playwright test"
  e2eFramework="playwright"
fi

if [ -f "$PROJECT_DIR/cypress.config.ts" ] || [ -f "$PROJECT_DIR/cypress.config.js" ]; then
  e2eCommand="npx cypress run"
  e2eFramework="cypress"
fi

# --- Output JSON ---

cat <<EOF
{
  "language": "$language",
  "framework": "$framework",
  "testCommand": "$testCommand",
  "testConfigFile": "$testConfigFile",
  "typeCheckCommand": "$typeCheckCommand",
  "lintCommand": "$lintCommand",
  "buildCommand": "$buildCommand",
  "e2eCommand": "$e2eCommand",
  "e2eFramework": "$e2eFramework",
  "packageManager": "$packageManager"
}
EOF
