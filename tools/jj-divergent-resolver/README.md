# JJ Divergent Commit Resolver

A TypeScript CLI tool to help resolve divergent commits in jj (Jujutsu) repositories.

## Features

- Automatically detects divergent commits in your jj repository
- Shows interdiff between divergent commits
- Interactive menu to choose resolution strategy:
  - **AL**: Abandon left commit
  - **AR**: Abandon right commit
  - **SL**: Squash left commit into right
  - **SR**: Squash right commit into left
  - **P**: Print current stack
- Confirmation prompts before destructive operations
- Shows operation history and updated tree after changes

## Prerequisites

- Node.js and npm/yarn installed
- `ts-node` and `typescript` packages
- `jj` (Jujutsu) version control system

## Installation

1. Navigate to the project directory:

```bash
cd /Users/felipe/.config/tools/jj-divergent-resolver
```

2. Install dependencies:

```bash
npm install -g ts-node typescript
# or locally in this directory:
npm install
```

3. Make the shell script executable:

```bash
chmod +x jj_divergent.sh
```

4. Make sure you're in a jj repository when running the tool

## Usage

### Basic Usage

```bash
# Run normally
./jj_divergent.sh

# Run in safe mode (asks confirmation before each jj command)
./jj_divergent.sh --safe

# Show help
./jj_divergent.sh --help
```

### Alternative Methods

#### Option 1: Run the shell wrapper

```bash
./jj_divergent.sh [--safe]
```

#### Option 2: Run directly with ts-node

```bash
ts-node jj_divergent_resolver.ts [--safe]
```

#### Option 3: Use npm script

```bash
npm run jj-divergent
```

#### Option 4: Create a symlink for global access

```bash
# Create a symlink in your PATH
ln -s /Users/felipe/.config/tools/jj-divergent-resolver/jj_divergent.sh /usr/local/bin/jj-divergent
# Then run from anywhere:
jj-divergent [--safe]
```

### Command Line Options

- `--safe`: Ask for confirmation before running any jj command (recommended for first-time users)
- `--help`: Show help message and exit

### Safe Mode

When using the `--safe` flag, the tool will ask for confirmation before executing any `jj` command. This is particularly useful when:

- You're new to the tool and want to review each operation
- Working with important commits that you want to be extra careful with
- Learning what the tool does step by step

Example safe mode interaction:

```
Execute: jj rebase -s "abc123+" -d "def456"
Rebase commit abc123 onto def456 (y/N): y
```

## How it works

1. **Detection**: Finds divergent change IDs using:

   ```bash
   jj log -T 'change_id ++ "\n"' --no-graph --color=never | sort | uniq -d
   ```

2. **Analysis**: Gets commit info for divergent changes and ensures exactly 2 commits exist

3. **Comparison**: Shows interdiff between the two commits

4. **Resolution**: Provides interactive menu for resolution strategies

5. **Execution**: Performs the chosen operation with confirmation

## Error Handling

- Aborts if more than 2 divergent commits are found
- Requires confirmation before any destructive operations
- Shows clear error messages for failed operations
- Validates jj repository before running

## Example Workflow

```
🔍 Checking for divergent commits...
Found 2 divergent change IDs: ['kzypumu', 'lsyrlxn']

📊 Commit comparison:
Left:  kzypumu abc123def
Right: lsyrlxn def456ghi

🔄 Interdiff:
[interdiff output shown here]

What would you like to do?
AL. Abandon left
AR. Abandon right
SL. Squash left into right
SR. Squash right into left
P. Print stack
Choose an option: SL

Squash left commit (abc123def) into right (def456ghi)? (y/N): y
[operation executed]

Updated tree:
[current state shown]
```
