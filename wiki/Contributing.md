# Contributing to Faith Journal

Thank you for your interest in contributing to Faith Journal! This guide will help you get started.

## Code of Conduct

By participating in this project, you agree to:

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect different viewpoints and experiences

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:

1. **Clear Title**: Descriptive title
2. **Description**: Detailed description of the bug
3. **Steps to Reproduce**: Step-by-step instructions
4. **Expected Behavior**: What should happen
5. **Actual Behavior**: What actually happens
6. **Screenshots**: If applicable
7. **Environment**: iOS version, device, app version

### Suggesting Features

Feature suggestions should include:

1. **Use Case**: Why is this feature needed?
2. **Proposed Solution**: How should it work?
3. **Alternatives**: Other solutions considered
4. **Additional Context**: Any other relevant information

### Pull Requests

1. **Fork the Repository**: Create your own fork
2. **Create a Branch**: Use descriptive branch names
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make Changes**: Follow coding standards
4. **Write Tests**: Add tests for new features
5. **Update Documentation**: Update relevant docs
6. **Commit Changes**: Use clear commit messages
7. **Push to Fork**: Push your branch
8. **Create Pull Request**: Submit PR with description

## Development Setup

See [Installation Guide](Installation-Guide.md) for setup instructions.

## Coding Standards

### Swift Style Guide

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions focused and small
- Add comments for complex logic

### Code Formatting

- Use Xcode's automatic formatting
- Indent with 4 spaces
- Maximum line length: 120 characters
- Remove trailing whitespace

### Naming Conventions

- **Types**: PascalCase (`JournalEntry`, `BibleService`)
- **Variables**: camelCase (`journalEntry`, `bibleService`)
- **Constants**: camelCase (`maxEntries`, `defaultTheme`)
- **Enums**: PascalCase with camelCase cases

### File Organization

```
Faith Journal/
├── Models/          # Data models
├── Views/           # SwiftUI views
├── Services/        # Business logic
└── Utils/           # Utilities
```

## Testing

### Unit Tests

- Write unit tests for business logic
- Test edge cases and error conditions
- Aim for high code coverage

### UI Tests

- Test critical user flows
- Test on multiple device sizes
- Test accessibility features

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme "Faith Journal"

# Run specific test
xcodebuild test -scheme "Faith Journal" -only-testing:FaithJournalTests/TestName
```

## Commit Messages

Use clear, descriptive commit messages:

```
Format: <type>(<scope>): <subject>

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- style: Code style changes (formatting)
- refactor: Code refactoring
- test: Adding or updating tests
- chore: Maintenance tasks

Examples:
feat(journal): Add mood tracking to journal entries
fix(prayer): Fix prayer status update bug
docs(readme): Update installation instructions
```

## Pull Request Process

1. **Update Documentation**: Update relevant docs
2. **Add Tests**: Add tests for new features
3. **Ensure Tests Pass**: All tests must pass
4. **Update CHANGELOG**: Document changes
5. **Request Review**: Request review from maintainers

## Review Process

Pull requests will be reviewed for:

- **Code Quality**: Follows coding standards
- **Functionality**: Works as intended
- **Tests**: Has appropriate test coverage
- **Documentation**: Documentation is updated
- **Performance**: No performance regressions

## Getting Help

If you need help:

1. Check existing [documentation](Home.md)
2. Search [existing issues](https://github.com/ronb12/Faith-Journal/issues)
3. Ask in [discussions](https://github.com/ronb12/Faith-Journal/discussions)
4. Create a new issue with your question

## Recognition

Contributors will be:

- Listed in CONTRIBUTORS.md
- Credited in release notes
- Acknowledged in the app (if applicable)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Related Documentation

- [Installation Guide](Installation-Guide.md)
- [Development Environment](Development-Environment.md)
- [Coding Standards](Development/Coding-Standards.md)
- [Testing Guide](Development/Testing-Guide.md)

Thank you for contributing to Faith Journal! 🙏

