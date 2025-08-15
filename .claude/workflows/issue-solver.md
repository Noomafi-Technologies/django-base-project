# Claude Issue Solver Workflow

This workflow automatically solves GitHub issues by:
1. Analyzing the issue requirements
2. Creating a new branch from main
3. Implementing the solution
4. Creating a pull request

## Usage

To use this workflow, simply provide an issue number or URL:

```
Solve issue #123
```

or

```
Solve https://github.com/Noomafi-Technologies/django-base-project/issues/123
```

## Workflow Steps

The Claude assistant will automatically:

1. **Fetch Issue Details**: Retrieve issue title, description, labels, and requirements
2. **Analyze Requirements**: Understand what needs to be implemented/fixed
3. **Create Branch**: Checkout main, pull latest changes, create feature branch
4. **Plan Implementation**: Break down the work into actionable steps
5. **Implement Solution**: Write/modify code to solve the issue
6. **Test Solution**: Run tests and verify the implementation works
7. **Commit Changes**: Create descriptive commit messages
8. **Create Pull Request**: Open PR with comprehensive description and test plan

## Branch Naming Convention

Branches are automatically named using the pattern:
- `feature/issue-{number}-{brief-description}` for new features
- `fix/issue-{number}-{brief-description}` for bug fixes
- `enhancement/issue-{number}-{brief-description}` for improvements

## Commit Message Format

Commits follow this format:
```
{type}: {brief description} (fixes #{issue-number})

{detailed description}

- {change 1}
- {change 2}
- {change 3}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Pull Request Template

PRs include:
- Issue reference and problem statement
- Solution overview
- Changes made
- Test plan
- Screenshots/examples (if applicable)
- Breaking changes (if any)

## Prerequisites

- GitHub CLI (`gh`) must be installed and authenticated
- Git repository must be properly configured
- Branch protection rules should allow Claude to create PRs

## Supported Issue Types

- 🐛 Bug fixes
- ✨ New features
- 🔧 Enhancements
- 📚 Documentation updates
- 🧪 Testing improvements
- 🔒 Security fixes
- 🎨 UI/UX improvements
- ⚡ Performance optimizations

## Example Usage

```
User: "Solve issue #45"

Claude will:
1. Fetch issue #45 details
2. Create branch: feature/issue-45-add-user-avatar-upload
3. Implement user avatar upload functionality
4. Add tests and documentation
5. Create PR with comprehensive description
```

This workflow makes issue resolution completely automated and consistent!