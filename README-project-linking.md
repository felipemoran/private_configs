# Project Directory Linking for Git Worktrees and Jujutsu Workspaces

This guide explains how to share WebStorm and VSCode/Cursor configurations across multiple git worktrees and Jujutsu (jj) workspaces while maintaining separate project instances.

## Overview

When working with multiple workspaces of the same repository, you'll want to:
- Share IDE configurations (settings, run configurations, etc.)
- Maintain separate project instances with visual differentiation
- Enable seamless switching between IDEs for the correct workspace

## Setup Process

### 1. Create a Jujutsu Workspace

From your source repository:

```bash
jj workspace add <workspace_dir> --name <workspace_name>
```

Example:
```bash
jj workspace add ~/projects/my-project-workspace --name feature-branch
```

### 2. Link Project Configurations

Use the linking script to share configurations:

```bash
link_project_configs.sh --src ~/projects/my-project/ --dest ~/projects/my-project-workspace
```

This creates symbolic links for IDE configuration directories, allowing both workspaces to share the same settings while maintaining separate project instances.

## IDE Configuration

### WebStorm Project Differentiation

1. **Change Project Color Theme**:
   - Open WebStorm in the new workspace
   - Go to `File → Settings → Appearance & Behavior → Appearance`
   - Select a different color theme or create a custom one
   - This helps visually distinguish between different workspace instances

2. **Project-Specific Settings**:
   - WebStorm will automatically detect it as a separate project instance
   - You can customize project-specific settings without affecting the source workspace

### VSCode/Cursor Workspace Configuration

1. **Create Workspace File**:
   - In the new workspace directory, create a `.vscode/settings.json` or workspace-specific configuration
   - This differentiates the project instance from others

2. **Use Peacock Extension for Visual Differentiation**:
   - Open VSCode/Cursor in the new workspace
   - Press `F1` to open command palette
   - Type "Peacock" and select "Peacock: Change to a Favorite Color"
   - Choose a distinctive color for this workspace window
   - The color will be applied to the activity bar, status bar, and title bar

## Workspace Management

### Removing a Workspace

When you no longer need a workspace:

1. **Remove from Jujutsu**:
   ```bash
   jj workspace forget <workspace_name>
   ```

2. **Delete Directory**:
   ```bash
   rm -rf <workspace_directory>
   ```

Example:
```bash
jj workspace forget feature-branch
rm -rf ~/projects/my-project-workspace
```

## Seamless IDE Switching

With proper configuration, you can use `Cmd+Shift+S` to toggle between WebStorm and Cursor, and both IDEs will automatically open the correct project instance for the current workspace.

**Setup Requirements**:
- Both IDEs should be configured to remember recently opened projects
- The linking script should preserve project-specific configurations
- Each workspace should have distinct visual themes (as configured above)

## Benefits

- **Consistent Configuration**: Share settings, plugins, and run configurations across workspaces
- **Visual Differentiation**: Easily identify which workspace you're working in
- **Efficient Workflow**: Quick switching between different versions of the same project
- **Reduced Setup Time**: No need to reconfigure IDEs for each workspace