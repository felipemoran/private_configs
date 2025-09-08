#!/usr/bin/env bash
# Portable (bash 3.2+/zsh) version: no associative arrays.
# Links IDE configuration files between worktrees of the same project.

set -euo pipefail

# IntelliJ IDEA configuration
IDEA_DIRS_TO_LINK=$'codeStyles\ninspectionProfiles\njsLinters\ndictionaries\ndataSources'
IDEA_FILES_TO_LINK=$'csv-editor.xml\njsLibraryMappings.xml\nprettier.xml\nmodules.xml\nvcs.xml\nwatcherTasks.xml\ngit_toolbox_prj.xml\ngit_toolbox_blame.xml\nGitLink.xml\nGitScopePro.xml\ngraphql-settings.xml\nsqldialects.xml\nsnyk.project.settings.xml\ndataSources.xml\ndataSources.local.xml\naws.xml\nremote-mappings.xml\n.name'

# VSCode configuration
VSCODE_DIRS_TO_LINK=$'launch'
VSCODE_FILES_TO_LINK=$'settings.json\nextensions.json\nkeybindings.json\nsnippets\ntasks.json'

# Common denylist
DENYLIST=$'shelf\n.gitignore\n.DS_Store'

# Membership check
in_list() { printf '%s\n' "$2" | grep -Fxq -- "$1"; }

# Append unique item to list variable
append_unique() {
  local varname="$1" item="$2"
  local current
  current="$(eval "printf '%s' \"\${$varname-}\"")"
  if ! in_list "$item" "$current"; then
    if [ -z "$current" ]; then
      eval "$varname=\$'$item'"
    else
      eval "$varname=\$'$current\n$item'"
    fi
  fi
}

link_project_configs() {
  # link_project_configs <SRC_PROJECT_DIR> <DEST_PROJECT_DIR> [--dry-run] [--copy] [--skip-workspace] [--clear] [--preserve-project-id]
  local SRC="${1:-}" DEST="${2:-}" DRY="${3:-}" COPY="${4:-}" SKIP_WORKSPACE="${5:-}" CLEAR="${6:-}" PRESERVE_PROJECT_ID="${7:-}"

  if [ -z "$SRC" ]; then
    echo "Usage: link_project_configs <SRC_PROJECT_DIR> <DEST_PROJECT_DIR> [--dry-run] [--copy] [--skip-workspace]" >&2
    return 2
  fi
  if [ "$DRY" != "--dry-run" ] && [ -z "${DEST:-}" ]; then
    echo "Usage: link_project_configs <SRC_PROJECT_DIR> <DEST_PROJECT_DIR> [--dry-run] [--copy] [--skip-workspace]" >&2
    return 2
  fi

  if ! cd "$SRC" 2>/dev/null; then echo "Source not found: $SRC" >&2; return 1; fi
  SRC="$PWD"; cd - >/dev/null || true

  if [ "$DRY" != "--dry-run" ]; then
    mkdir -p "$DEST"
    if ! cd "$DEST" 2>/dev/null; then echo "Destination not accessible: $DEST" >&2; return 1; fi
    DEST="$PWD"; cd - >/dev/null || true
  fi

  echo "Source: $SRC"
  if [ "$DRY" = "--dry-run" ]; then
    echo "Mode  : DRY RUN (no changes)"
  else
    echo "Dest  : $DEST"
  fi
  if [ "$COPY" = "--copy" ]; then
    echo "Action: COPY files (instead of linking)"
  else
    echo "Action: LINK files (default)"
  fi
  if [ "$SKIP_WORKSPACE" = "--skip-workspace" ]; then
    echo "Option: SKIP workspace.xml file"
  fi
  if [ "$CLEAR" = "--clear" ]; then
    echo "Option: CLEAR existing directories before linking/copying"
  fi
  if [ "$PRESERVE_PROJECT_ID" = "--preserve-project-id" ]; then
    echo "Option: PRESERVE existing project ID in workspace.xml"
  fi
  
  # Show path variables for identifier replacement
  local src_rel_path dest_rel_path
  src_rel_path="$(get_relative_path "$SRC")"
  dest_rel_path="$(get_relative_path "${DEST:-$SRC}")"
  echo "SRC_PATH : $src_rel_path"
  echo "DEST_PATH: $dest_rel_path"
  echo

  # Helper: link with backup
  _link_one() {
    local src="$1" dst="$2"
    [ -e "$src" ] || { echo "skip (missing): $src"; return 0; }
    if [ -L "$dst" ]; then
      local target; target="$(readlink "$dst" || true)"
      [ "$target" = "$src" ] && { echo "ok (already linked): $dst"; return 0; }
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      local ts; ts="$(date +%Y%m%d-%H%M%S)"
      mv -f "$dst" "${dst}.bak-${ts}"
      echo "backup: $dst -> ${dst}.bak-${ts}"
    fi
    ln -s "$src" "$dst"
    echo "link:   $dst -> $src"
  }

  # Helper: copy with backup
  _copy_one() {
    local src="$1" dst="$2"
    [ -e "$src" ] || { echo "skip (missing): $src"; return 0; }
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      local ts; ts="$(date +%Y%m%d-%H%M%S)"
      mv -f "$dst" "${dst}.bak-${ts}"
      echo "backup: $dst -> ${dst}.bak-${ts}"
    fi
    cp "$src" "$dst"
    echo "copy:   $dst <- $src"
  }

  # Link IntelliJ IDEA configuration
  if [ -d "$SRC/.idea" ]; then
    echo "Linking IntelliJ IDEA configuration..."
    
    # Auto-include *.iml files
    local IDEA_FILES_WITH_IML="$IDEA_FILES_TO_LINK"
    while IFS= read -r -d '' iml; do
      append_unique IDEA_FILES_WITH_IML "$(basename "$iml")"
    done < <(find "$SRC/.idea" -maxdepth 1 -type f -name '*.iml' -print0 2>/dev/null || true)

    # Build EXPECTED list for IDEA
    local IDEA_EXPECTED
    IDEA_EXPECTED="$(printf '%s\n' "$IDEA_DIRS_TO_LINK"; printf '%s\n' "$IDEA_FILES_WITH_IML"; printf '%s\n' "$DENYLIST"; echo workspace.xml | sort -u)"

    # Scan for unexpected entries in .idea
    local idea_unexpected=''
    while IFS= read -r name; do
      [ "$name" = "." ] || [ "$name" = ".." ] && continue
      if ! in_list "$name" "$IDEA_EXPECTED"; then
        append_unique idea_unexpected "$name"
      fi
    done < <(LC_ALL=C ls -A "$SRC/.idea")

    if [ -n "${idea_unexpected:-}" ]; then
      echo "ERROR: Unexpected files/dirs found in $SRC/.idea:"
      printf '%s\n' "$idea_unexpected" | while IFS= read -r u; do
        if [ -d "$SRC/.idea/$u" ]; then
          echo "  - $u/     (DIR)  → add to IDEA_DIRS_TO_LINK or DENYLIST"
        else
          echo "  - $u      (FILE) → add to IDEA_FILES_TO_LINK or DENYLIST"
        fi
      done
      echo
      echo "Edit the script to include/skip these before proceeding."
      return 1
    fi

    if [ "$DRY" != "--dry-run" ]; then
      if [ "$CLEAR" = "--clear" ] && [ -d "$DEST/.idea" ]; then
        echo "Clearing existing $DEST/.idea directory..."
        rm -rf "$DEST/.idea"
      fi
      mkdir -p "$DEST/.idea"
    fi

    if [ "$DRY" = "--dry-run" ]; then
      if [ "$COPY" = "--copy" ]; then
        echo "  Planned IDEA copies (preview):"
      else
        echo "  Planned IDEA links (preview):"
      fi
      printf '%s\n' "$IDEA_DIRS_TO_LINK" | while IFS= read -r d; do
        [ -e "$SRC/.idea/$d" ] && echo "    DIR  .idea/$d"
      done
      printf '%s\n' "$IDEA_FILES_WITH_IML" | while IFS= read -r f; do
        [ -e "$SRC/.idea/$f" ] && echo "    FILE .idea/$f"
      done
      if [ "$SKIP_WORKSPACE" != "--skip-workspace" ] && [ -e "$SRC/.idea/workspace.xml" ]; then
        echo "    COPY .idea/workspace.xml"
      fi
    else
      if [ "$COPY" = "--copy" ]; then
        printf '%s\n' "$IDEA_DIRS_TO_LINK" | while IFS= read -r d; do
          in_list "$d" "$DENYLIST" && continue
          [ -d "$SRC/.idea/$d" ] && cp -r "$SRC/.idea/$d" "$DEST/.idea/$d" && echo "copy:   $DEST/.idea/$d <- $SRC/.idea/$d"
        done
        printf '%s\n' "$IDEA_FILES_WITH_IML" | while IFS= read -r f; do
          in_list "$f" "$DENYLIST" && continue
          _copy_one "$SRC/.idea/$f" "$DEST/.idea/$f"
        done
      else
        printf '%s\n' "$IDEA_DIRS_TO_LINK" | while IFS= read -r d; do
          in_list "$d" "$DENYLIST" && continue
          _link_one "$SRC/.idea/$d" "$DEST/.idea/$d"
        done
        printf '%s\n' "$IDEA_FILES_WITH_IML" | while IFS= read -r f; do
          in_list "$f" "$DENYLIST" && continue
          _link_one "$SRC/.idea/$f" "$DEST/.idea/$f"
        done
      fi
      if [ "$SKIP_WORKSPACE" != "--skip-workspace" ] && [ -e "$SRC/.idea/workspace.xml" ]; then
        # Extract existing project ID from destination if preserving
        local existing_project_id=""
        if [ "$PRESERVE_PROJECT_ID" = "--preserve-project-id" ] && [ -f "$DEST/.idea/workspace.xml" ]; then
          existing_project_id="$(extract_project_id "$DEST/.idea/workspace.xml")"
        fi
        
        _copy_one "$SRC/.idea/workspace.xml" "$DEST/.idea/workspace.xml"
        update_project_identifiers "$SRC" "$DEST" "$DEST/.idea/workspace.xml"
        
        # Restore project ID if preserving and we found one
        if [ "$PRESERVE_PROJECT_ID" = "--preserve-project-id" ] && [ -n "$existing_project_id" ]; then
          preserve_project_id "$DEST/.idea/workspace.xml" "$existing_project_id"
          echo "preserved project ID: $existing_project_id"
        fi
      fi
    fi
  fi

  # Link VSCode configuration
  if [ -d "$SRC/.vscode" ]; then
    echo "Linking VSCode configuration..."
    
    # Build EXPECTED list for VSCode (including *.code-workspace pattern)
    local VSCODE_EXPECTED
    VSCODE_EXPECTED="$(printf '%s\n' "$VSCODE_DIRS_TO_LINK"; printf '%s\n' "$VSCODE_FILES_TO_LINK"; printf '%s\n' "$DENYLIST" | sort -u)"

    # Scan for unexpected entries in .vscode
    local vscode_unexpected=''
    while IFS= read -r name; do
      [ "$name" = "." ] || [ "$name" = ".." ] && continue
      # Skip workspace files (*.code-workspace)
      case "$name" in
        *.code-workspace) continue ;;
      esac
      if ! in_list "$name" "$VSCODE_EXPECTED"; then
        append_unique vscode_unexpected "$name"
      fi
    done < <(LC_ALL=C ls -A "$SRC/.vscode")

    if [ -n "${vscode_unexpected:-}" ]; then
      echo "ERROR: Unexpected files/dirs found in $SRC/.vscode:"
      printf '%s\n' "$vscode_unexpected" | while IFS= read -r u; do
        if [ -d "$SRC/.vscode/$u" ]; then
          echo "  - $u/     (DIR)  → add to VSCODE_DIRS_TO_LINK or DENYLIST"
        else
          echo "  - $u      (FILE) → add to VSCODE_FILES_TO_LINK or DENYLIST"
        fi
      done
      echo
      echo "Edit the script to include/skip these before proceeding."
      return 1
    fi

    if [ "$DRY" != "--dry-run" ]; then
      if [ "$CLEAR" = "--clear" ] && [ -d "$DEST/.vscode" ]; then
        echo "Clearing existing $DEST/.vscode directory..."
        rm -rf "$DEST/.vscode"
      fi
      mkdir -p "$DEST/.vscode"
    fi

    if [ "$DRY" = "--dry-run" ]; then
      if [ "$COPY" = "--copy" ]; then
        echo "  Planned VSCode copies (preview):"
      else
        echo "  Planned VSCode links (preview):"
      fi
      printf '%s\n' "$VSCODE_DIRS_TO_LINK" | while IFS= read -r d; do
        [ -e "$SRC/.vscode/$d" ] && echo "    DIR  .vscode/$d"
      done
      printf '%s\n' "$VSCODE_FILES_TO_LINK" | while IFS= read -r f; do
        [ -e "$SRC/.vscode/$f" ] && echo "    FILE .vscode/$f"
      done
      echo "    SKIP .vscode/*.code-workspace (workspace files kept separate)"
    else
      if [ "$COPY" = "--copy" ]; then
        printf '%s\n' "$VSCODE_DIRS_TO_LINK" | while IFS= read -r d; do
          in_list "$d" "$DENYLIST" && continue
          [ -d "$SRC/.vscode/$d" ] && cp -r "$SRC/.vscode/$d" "$DEST/.vscode/$d" && echo "copy:   $DEST/.vscode/$d <- $SRC/.vscode/$d"
        done
        printf '%s\n' "$VSCODE_FILES_TO_LINK" | while IFS= read -r f; do
          in_list "$f" "$DENYLIST" && continue
          _copy_one "$SRC/.vscode/$f" "$DEST/.vscode/$f"
        done
      else
        printf '%s\n' "$VSCODE_DIRS_TO_LINK" | while IFS= read -r d; do
          in_list "$d" "$DENYLIST" && continue
          _link_one "$SRC/.vscode/$d" "$DEST/.vscode/$d"
        done
        printf '%s\n' "$VSCODE_FILES_TO_LINK" | while IFS= read -r f; do
          in_list "$f" "$DENYLIST" && continue
          _link_one "$SRC/.vscode/$f" "$DEST/.vscode/$f"
        done
      fi
      echo "  Skipping workspace files (*.code-workspace) - keeping separate per worktree"
    fi
  fi

  if [ "$DRY" = "--dry-run" ]; then
    echo
    echo "Known-skipped (denylist):"
    printf '%s\n' "$DENYLIST" | while IFS= read -r skip; do
      [ -e "$SRC/.idea/$skip" ] && echo "  SKIP .idea/$skip"
      [ -e "$SRC/.vscode/$skip" ] && echo "  SKIP .vscode/$skip"
    done
    return 0
  fi

  echo "Done."
}

# Commands for updating project identifiers when copying to a new directory
# Extract relative paths from HOME for sed replacement
get_relative_path() {
  local full_path="$1"
  echo "${full_path#$HOME/}"
}

update_project_identifiers() {
  local src_dir="$1" dest_dir="$2" target_file="$3"
  local src_rel_path dest_rel_path
  
  src_rel_path="$(get_relative_path "$src_dir")"
  dest_rel_path="$(get_relative_path "$dest_dir")"
  
  sed -i '' 's|'$src_rel_path'|'$dest_rel_path'|g' "$target_file"
}

# Extract project ID from workspace.xml
extract_project_id() {
  local workspace_file="$1"
  if [ -f "$workspace_file" ]; then
    grep -o '<component name="ProjectId" id="[^"]*"' "$workspace_file" | grep -o 'id="[^"]*"' | sed 's/id="//;s/"//'
  fi
}

# Preserve project ID in workspace.xml
preserve_project_id() {
  local workspace_file="$1" project_id="$2"
  if [ -n "$project_id" ] && [ -f "$workspace_file" ]; then
    # Check if ProjectId component exists
    if grep -q '<component name="ProjectId"' "$workspace_file"; then
      # Replace existing ProjectId
      sed -i '' "s|<component name=\"ProjectId\" id=\"[^\"]*\"|<component name=\"ProjectId\" id=\"$project_id\"|g" "$workspace_file"
    else
      # Add ProjectId component after <project> tag
      sed -i '' "/<project[^>]*>/a\\
  <component name=\"ProjectId\" id=\"$project_id\" />
" "$workspace_file"
    fi
  fi
}

# CLI entrypoint
if [ "${BASH_SOURCE[0]-}" = "$0" ]; then
  SRC="" DEST="" DRY="" COPY="" SKIP_WORKSPACE="" CLEAR="" PRESERVE_PROJECT_ID=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --src|-s)  SRC="${2:-}"; shift 2 ;;
      --dest|-d) DEST="${2:-}"; shift 2 ;;
      --dry-run) DRY="--dry-run"; shift ;;
      --copy) COPY="--copy"; shift ;;
      --skip-workspace) SKIP_WORKSPACE="--skip-workspace"; shift ;;
      --clear) CLEAR="--clear"; shift ;;
      --preserve-project-id) PRESERVE_PROJECT_ID="--preserve-project-id"; shift ;;
      -h|--help)
        echo "Usage: $(basename "$0") --src <PROJECT_DIR> --dest <PROJECT_DIR> [OPTIONS]"
        echo "Links IDE configuration files between project worktrees."
        echo ""
        echo "Options:"
        echo "  --src, -s         Source project directory (containing .idea/.vscode)"
        echo "  --dest, -d        Destination project directory"
        echo "  --dry-run         Show what would be linked without making changes"
        echo "  --copy               Copy files instead of creating symbolic links"
        echo "  --skip-workspace     Skip copying workspace.xml file"
        echo "  --clear              Clear existing .idea/.vscode directories before operation"
        echo "  --preserve-project-id Preserve existing ProjectId in destination workspace.xml"
        echo "  --help, -h           Show this help message"
        echo ""
        echo "Both IntelliJ IDEA (.idea) and VSCode (.vscode) configurations are processed."
        echo "Workspace files are copied (not linked) and kept separate per worktree."
        echo "By default, files are symbolically linked. Use --copy to copy instead."
        exit 0 ;;
      *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  [ -z "$SRC" ] && { echo "Error: --src required" >&2; exit 2; }
  [ -z "$DEST" ] && [ "$DRY" != "--dry-run" ] && { echo "Error: --dest required unless --dry-run" >&2; exit 2; }
  link_project_configs "$SRC" "${DEST:-}" "${DRY:-}" "${COPY:-}" "${SKIP_WORKSPACE:-}" "${CLEAR:-}" "${PRESERVE_PROJECT_ID:-}"
fi
