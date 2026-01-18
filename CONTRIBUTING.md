# Contributing

Thanks for your interest in contributing! 🎉  
This project is open to improvements via Issues and Pull Requests.

## Before you start
- Please search existing **Issues** and **Pull Requests** to avoid duplicates.
- For bigger changes, open an **Issue** first to discuss the approach.

## How to contribute
1. **Fork** this repository
2. Create a branch from `main`:
   - `feature/<short-description>` for new features
   - `fix/<short-description>` for bug fixes
   - `docs/<short-description>` for documentation changes
3. Make your changes with clear, focused commits
4. Test your changes (see below)
5. Open a **Pull Request** to `main`

## Development setup

### Requirements
- **Delphi IDE** (Community Edition or higher)
  - Tested with Delphi 11+, should work with Delphi 10.3+ (FireDAC support required)
- **Boss** (Delphi Package Manager) - recommended for dependency management
- **Git** for version control

### Setup Steps
1. Clone your fork:
   ```bash
   git clone <your-fork-url>
   cd DBRestConnector
   ```

2. Install dependencies via Boss:
   ```bash
   boss install horse
   boss install horse-jhonson
   ```

3. Open `Darest.dproj` in Delphi IDE

4. Build the project (Shift+F9)

5. Copy the `swagger/` folder to your output directory (e.g., `Win32/Debug/swagger/`)

6. Run and test (F9)

## Testing / Validation

Before opening a PR, please verify:

### Build & Compilation
- ✅ Project compiles without errors or warnings
- ✅ All units are properly referenced
- ✅ No memory leaks (use FastMM4 or similar if possible)

### Functional Testing
Test with at least one database (SQLite recommended for quick testing):
- ✅ CRUD operations work correctly:
  - GET `/data/:table` (list records)
  - GET `/data/:table/:id` (get single record)
  - POST `/data/:table` (insert)
  - PUT `/data/:table/:id` (update)
  - DELETE `/data/:table/:id` (delete)
- ✅ Swagger UI loads and displays correct endpoints
- ✅ Table permissions are respected
- ✅ Configuration persists after restart

### UI/Behavior Changes
If your change affects UI or behavior:
- Include **screenshots** or **screen recordings**
- Describe **how to test** the change
- Note any **breaking changes**

## Pull Request guidelines
A good PR should:
- Explain **what** changed and **why**
- Be as small and focused as possible
- Include steps to test / reproduce (especially for bug fixes)
- Update documentation if needed (README, comments, etc.)
- Follow the existing code architecture and patterns

## Code style

### Delphi Coding Standards
- **Follow Delphi naming conventions**:
  - Classes: `TClassName`
  - Interfaces: `IInterfaceName`
  - Private fields: `FFieldName`
  - Parameters: `AParameterName`
- **Use English** for all comments and identifiers
- **Add comments** to complex logic, but avoid obvious comments
- **Keep it simple** - Prefer clarity over cleverness

### Project-Specific Guidelines
- **Unit naming**: `Darest.<Module>.pas` (e.g., `Darest.Logic.pas`, `Darest.Types.pas`)
- **Error handling**: Use try-finally blocks for resource cleanup
- **Memory management**: Always free created objects
- **Database queries**: Use parameterized queries to prevent SQL injection

### What to Avoid
- ❌ Unrelated formatting changes in the same PR
- ❌ Commented-out code (remove it or explain why it's there)
- ❌ Hard-coded values (use constants or configuration)
- ❌ Breaking changes without discussion

## Reporting bugs / requesting features
Open an Issue and include:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Logs/screenshots (if available)
- Your environment (OS, version, etc.)

## License
By contributing, you agree that your contributions will be licensed under the same license as this repository.
