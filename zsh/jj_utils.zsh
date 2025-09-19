alias jj=jj_guard.sh

alias j=jj
alias k=jj
alias kk=jj

alias je='jj edit -r'
alias jwip='je "wipcurrent()"'
# alias je='echo "Should you not be using new+squash?"'
# alias jer='jj edit -r'
# alias jer='echo "Should you not be using new+squash?"'
alias jsq='jj squash -i --keep-emptied'
alias jnext='je @+ && jj'
alias jn='jnext'
alias jnn='je @++ && jj'
alias jnnn='je @+++ && jj'
alias jprev='je @- && jj'
alias jp='jprev'
alias jpp='je @-- && jj'
alias jppp='je @--- && jj'
alias jsync='jj git fetch && jj retrunk && jj simplify && jj'
alias jra='jj rebase -r @ -A @-'
alias jrb='jj rebase -r @ -B @-'
alias jdev='je DEV_CHANGES'
alias jrepush='check_prettier_before_push && jj tug && jj push && jj new -d "description(\"MEGA MERGE\")" && jj'
alias jrepush-force='jj tug && jj push && jj new -d DEV_CHANGES && jj'
alias jre='jrepush'
alias jre-force='jrepush-force'
alias jrtr='jj retrunk && jj simplify && jj'
alias jrtrm='jj retrunk-megamerge && jj simplify && jj'
alias jprep='jj prepare -r @ && jj'
alias jpprep='jp && jprep'
alias jfix='jj fix-pr'
alias jfp='jj fix-pr'
alias jdiffall='jj log -s -r "wipstack()" -T builtin_log_comfortable'
alias jstack='jj log -r "stack()"'
alias jdm='jj desc -m'
alias jd='jj desc'
alias js='jj squash'
alias jsu='jj squash -u'
alias jsd='jj squash -i --into DEV_CHANGES'
alias jlogfridge='jj log -r "stack(FRIDGE)"'
alias jpark='jj new -d "trunk()"'

jrt() {
  # Check if current commit is empty
  local fileCount
  fileCount=$(jj diff -r @ --name-only | wc -l)
  if [ "$fileCount" -gt 0 ]; then
    echo "📝 Current commit is not empty, creating new commit..."
    jj new -A @
  fi
  
  jj rebase-trunk && jj desc -m "Merge with $(jj_trunk_name)" && jj
}


jj_trunk_name() {
  local trunk_branch
  trunk_branch=$(jj bookmark list --all -T 'name ++ "@" ++ remote ++ "\n"')
  if echo "$trunk_branch" | grep -q "develop@origin"; then
    echo "develop"
  elif echo "$trunk_branch" | grep -q "main@origin"; then
    echo "main"
  else
    echo "trunk"
  fi
}


mkbranchname() {
  echo "$1" | tr "[:upper:]" "[:lower:]" |
    sed -E "s/[^a-z0-9._-]+/-/g" |
    sed -E "s/^[-.]+|[-.]+$//g" |
    sed -E "s/[-.]{2,}/-/g"
}

get_changeset_description() {
  jj st | sed -E 's/\x1b\[[0-9;]*m//g' |  # remove ANSI escape sequences
  awk -F' : ' '/^Working copy.*: / {
    # remove commit ID and change ID
    desc = $2
    n = split(desc, words, " ")
    if (n > 2) {
      # print from the third word onward
      for (i = 3; i <= n; i++) printf("%s%s", words[i], (i < n ? " " : "\n"))
    } else {
      print desc
    }
    exit
  }'
}

mkbranch() {
  local input="$*"
  if [[ -z "$input" ]]; then
    input=$(get_changeset_description)
  fi

  if [[ -z "$input" ]]; then
    echo "Error: No input and could not extract changeset description." >&2
    return 1
  fi

  local branch
  branch=$(mkbranchname "$input")
  jj bc "felipe/$branch"
}

check_prettier_before_push() {
  local dry_run=false
  
  # Parse arguments
  if [[ "$1" == "--dry-run" ]]; then
    dry_run=true
    echo "🔍 Checking prettier formatting (dry run)..."
  else
    echo "🔍 Checking prettier formatting before push..."
  fi
  
  # Get list of changed files using change IDs approach
  local changed_files
  changed_files=$(
    jj log -r "fork_point(@ | trunk()).. & ::@ & mine()" --no-graph -T 'change_id ++ "\n"' --color=never | \
    while read -r change_id; do
      [[ -n "$change_id" ]] && jj diff -r "$change_id" --name-only
    done | sort -u
  )
  
  if [[ -z "$changed_files" ]]; then
    echo "✅ No changed files to check"
    return 0
  fi
  
  echo "📝 Checking files:"
  echo "$changed_files" | sed 's/^/  - /'
  
  # Filter out deleted files (files that don't exist on filesystem)
  # and only keep js, ts, jsx, tsx files (excluding generated files)
  local existing_files
  existing_files=$(echo "$changed_files" | while read -r file; do
    if [[ -n "$file" && -f "$file" ]]; then
      # Skip files with "generated" in their path
      if [[ "$file" == *generated* ]]; then
        continue
      fi
      case "$file" in
        *.js|*.ts|*.jsx|*.tsx)
          echo "$file"
          ;;
      esac
    fi
  done)
  
  if [[ -z "$existing_files" ]]; then
    echo "✅ No existing JS/TS files to check"
    return 0
  fi
  
  # Check if prettier would make changes (without actually changing files)
  local prettier_output
  if ! prettier_output=$(echo "$existing_files" | xargs prettier --check 2>&1); then
    echo "⚠️  Prettier formatting issues found!"
    echo "$prettier_output"
    
    if [[ "$dry_run" == true ]]; then
      echo "🔍 DRY RUN: Would create a new commit and apply prettier fixes."
      echo "🔍 DRY RUN: Run without --dry-run to apply the fixes."
      return 1
    else
      # Create new commit for prettier fixes
      echo "📝 Creating new commit for prettier fixes..."
      jj new -A @ -m "Format with prettier"
      
      # Fix the files
      echo "$existing_files" | xargs prettier --write
      
      echo "⚠️  STOPPED: Prettier fixes have been applied in a new commit."
      echo "⚠️  Please review the changes and run the push command again."
      return 1
    fi
  fi
  
  echo "✅ All files pass prettier check"
  return 0
}


jprfridge() {
  if [ -z "$1" ]; then
    echo "Usage: jjrebase <param>"
    return 1
  fi

  local param="$1"

  jj rebase -s "${param}+" -d "${param}+- ~ ${param}" \
    && jj rebase -s FRIDGE -d FRIDGE- -d "${param}"
}

# Generic function to toggle prefix in commit description
jj_toggle_prefix() {
  local prefix="$1"
  local change_id="$2"
  
  if [[ -z "$prefix" || -z "$change_id" ]]; then
    echo "Usage: jj_toggle_prefix <prefix> <change_id>"
    echo "Example: jj_toggle_prefix 'MQ' @"
    return 1
  fi
  
  # Get current description
  local current_desc
  current_desc=$(jj --ignore-working-copy log -r "$change_id" -T "description" --no-graph)
  
  if [[ -z "$current_desc" ]]; then
    echo "Error: Could not get description for change ID: $change_id"
    return 1
  fi
  
  local new_desc
  local prefix_pattern="${prefix}: "
  
  # Check if the prefix already exists
  if [[ "$current_desc" == "$prefix_pattern"* ]]; then
    # Remove the prefix
    new_desc="${current_desc#$prefix_pattern}"
    echo "Removing '$prefix' prefix from commit description"
  else
    # Add the prefix
    new_desc="${prefix_pattern}${current_desc}"
    echo "Adding '$prefix' prefix to commit description"
  fi
  
  # Set the new description
  jj --ignore-working-copy desc -m "$new_desc" -r "$change_id"
  
  if [[ $? -eq 0 ]]; then
    echo "✅ Successfully toggled '$prefix' prefix"
    echo "New description: $new_desc"
  else
    echo "❌ Failed to update description"
    return 1
  fi
}

# Toggle MQ prefix for a commit
jj_toggle_mq() {
  local change_id="${1:-@}"
  jj_toggle_prefix "MQ" "$change_id"
}

# Toggle WIP prefix for a commit
jj_toggle_wip() {
  local change_id="${1:-@}"
  jj_toggle_prefix "WIP" "$change_id"
}

# Aliases for convenience
alias jtmq='jj_toggle_mq'
alias jtwip='jj_toggle_wip'

# Get operation ID from approximately N days ago (default: 30 days / 1 month)
# Usage: jj_op_month_ago [days]
# Example: jj_op_month_ago 7  # Get op from 1 week ago
jj_op_month_ago() {
  local target_days="${1:-30}"
  local num_ops=10000
  local max_ops=100000  # Upper limit to avoid going too far
  
  while (( num_ops <= max_ops )); do
    echo "🔍 Searching through $num_ops operations..." >&2
    
    # Parse operation log and find the operation closest to target_days ago
    local result
    result=$(jj op log -n "$num_ops" --color=never 2>/dev/null | awk -v target="$target_days" '
      /^[@○]/ {
        # Extract operation ID (first field after @ or ○)
        op_id = $2
        
        # Look for timestamp pattern: "N <unit> ago,"
        for (i = 3; i <= NF; i++) {
          if ($i ~ /^ago,?$/ && i >= 3) {
            time_value = $(i-2)
            time_unit = $(i-1)
            
            # Remove trailing "s" from unit
            gsub(/s$/, "", time_unit)
            
            # Convert to days
            days = 0
            if (time_unit == "second") days = time_value / 86400.0
            else if (time_unit == "minute") days = time_value / 1440.0
            else if (time_unit == "hour") days = time_value / 24.0
            else if (time_unit == "day") days = time_value
            else if (time_unit == "week") days = time_value * 7
            else if (time_unit == "month") days = time_value * 30
            else if (time_unit == "year") days = time_value * 365
            
            # Track the oldest operation we found
            if (max_days == "" || days > max_days) {
              max_days = days
            }
            
            # Find the operation closest to target days (must be >= target)
            if (days >= target) {
              days_diff = days - target
              if (best_op_id == "" || days_diff < best_days_diff) {
                best_days_diff = days_diff
                best_op_id = op_id
                best_days = days
              }
            }
            break
          }
        }
      }
      END {
        if (best_op_id != "") {
          print "FOUND:" best_op_id
        } else {
          print "MAX_DAYS:" max_days
        }
      }
    ')
    
    if [[ "$result" == FOUND:* ]]; then
      # Extract and return the operation ID
      echo "${result#FOUND:}"
      return 0
    elif [[ "$result" == MAX_DAYS:* ]]; then
      local max_days="${result#MAX_DAYS:}"
      if [[ -n "$max_days" && "$max_days" != "" ]]; then
        echo "⚠️  Oldest operation found is only ${max_days} days old, need ${target_days} days" >&2
      fi
      # Double the number of operations and try again
      num_ops=$(( num_ops * 2 ))
    else
      echo "Error: Failed to parse operation log" >&2
      return 1
    fi
  done
  
  echo "Error: Reached maximum search limit ($max_ops operations) without finding operation from $target_days days ago" >&2
  return 1
}

# Count the total number of operations in the log
# Usage: jj_op_count
jj_op_count() {
  local count
  count=$(jj op log --color=never | grep -c "^[@○]")
  
  echo "📊 Total operations in log: $count"
  return 0
}

# Trim operation history older than N days
# Usage: jj_op_trim [--dry-run] [--yes] <days>
# Example: jj_op_trim 30                # Trim ops older than 30 days
#          jj_op_trim --dry-run 30       # Show what would be trimmed
#          jj_op_trim --yes 30           # Skip confirmation prompt
jj_op_trim() {
  local dry_run=false
  local skip_confirm=false
  local days=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      --yes|-y)
        skip_confirm=true
        shift
        ;;
      *)
        if [[ -z "$days" ]]; then
          days="$1"
        else
          echo "Error: Unexpected argument: $1" >&2
          echo "Usage: jj_op_trim [--dry-run] [--yes] <days>" >&2
          return 1
        fi
        shift
        ;;
    esac
  done
  
  if [[ -z "$days" ]]; then
    echo "Error: Number of days is required" >&2
    echo "Usage: jj_op_trim [--dry-run] [--yes] <days>" >&2
    return 1
  fi
  
  echo "🔍 Finding operation from approximately $days days ago..." >&2
  
  # Find the operation ID from N days ago
  local op_id
  op_id=$(jj_op_month_ago "$days" 2>&1)
  local exit_code=$?
  
  if [[ $exit_code -ne 0 ]]; then
    echo "Error: Failed to find operation from $days days ago" >&2
    echo "$op_id" >&2
    return 1
  fi
  
  # Remove the progress message from op_id if it got captured
  op_id=$(echo "$op_id" | tail -1)
  
  echo "📍 Found operation ID: $op_id" >&2
  
  # Get info about the target operation
  local op_info
  op_info=$(jj op log --color=never -n 100000 | grep -A 2 "^[@○].*$op_id" | head -3)
  
  echo "" >&2
  echo "🎯 Target operation (and its ancestors will be abandoned):" >&2
  echo "$op_info" >&2
  
  echo "" >&2
  echo "🗑️  Preview: This will abandon operation $op_id and ALL its ancestor operations" >&2
  echo "🗑️  (All operations older than this one)" >&2
  echo "" >&2
  
  if [[ "$dry_run" == true ]]; then
    echo "🔍 DRY RUN: Would execute: jj op abandon ..$op_id" >&2
    echo "🔍 DRY RUN: Run without --dry-run to actually trim the history." >&2
    return 0
  fi
  
  # Confirm before proceeding
  if [[ "$skip_confirm" == false ]]; then
    echo "⚠️  This will permanently abandon operation $op_id and all its ancestors!" >&2
    echo "⚠️  Abandoned operations can be garbage collected later with 'jj util gc'" >&2
    read "confirm?Continue? (y/N): "
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "❌ Aborted." >&2
      return 1
    fi
  else
    echo "⚠️  Proceeding without confirmation (--yes flag)" >&2
  fi
  
  echo "" >&2
  echo "🗑️  Abandoning operations..." >&2
  jj op abandon "..$op_id"
  
  if [[ $? -eq 0 ]]; then
    echo "✅ Successfully abandoned operations older than $days days" >&2
    echo "💡 Tip: Run 'jj util gc' to garbage collect abandoned objects" >&2
  else
    echo "❌ Failed to abandon operations" >&2
    return 1
  fi
}

# Remove TODO comments that were added in a jj diff
# Usage: jj diff --from TARGET --tool :git | jj_remove_todos
# Or: jj_remove_todos TARGET
jj_remove_todos() {
  local target_rev="${1}"
  local diff_output
  
  if [[ -n "$target_rev" ]]; then
    # If a target revision is provided, generate the diff
    diff_output=$(jj diff --from "$target_rev" --tool :git)
  else
    # Otherwise, read from stdin
    diff_output=$(cat)
  fi
  
  if [[ -z "$diff_output" ]]; then
    echo "Error: No diff provided" >&2
    echo "Usage: jj diff --from TARGET --tool :git | jj_remove_todos" >&2
    echo "   or: jj_remove_todos TARGET" >&2
    return 1
  fi
  
  # Strip ANSI color codes from the diff
  diff_output=$(echo "$diff_output" | sed -E 's/\x1b\[[0-9;]*m//g')
  
  # Parse the diff to find TODO comments that were added
  # Format: file_path:line_number:todo_line_content
  local todos_to_remove
  todos_to_remove=$(echo "$diff_output" | awk '
    /^diff --git/ {
      # Extract target file path (the "b/" version)
      match($0, /b\/[^ ]+/)
      current_file = substr($0, RSTART+2, RLENGTH-2)
      line_num = 0
      next
    }
    /^@@/ {
      # Parse hunk header to get starting line number
      # Format: @@ -old_start,old_count +new_start,new_count @@
      match($0, /\+[0-9]+/)
      line_num = substr($0, RSTART+1, RLENGTH-1)
      next
    }
    /^[+]/ && !/^[+]{3}/ {
      # This is an added line (starts with +, but not +++)
      line_content = substr($0, 2)  # Remove the leading +
      
      # Check if this line contains a TODO comment
      # Matches: // TODO, /* TODO, # TODO, * TODO (in multi-line comments)
      if (line_content ~ /\/\/.*TODO/ || line_content ~ /\/\*.*TODO/ || line_content ~ /#.*TODO/ || line_content ~ /\*.*TODO/) {
        print current_file ":" line_num ":" line_content
      }
      line_num++
      next
    }
    /^[ ]/ {
      # Context line (unchanged)
      line_num++
      next
    }
  ')
  
  if [[ -z "$todos_to_remove" ]]; then
    echo "✅ No TODO comments found in added lines"
    return 0
  fi
  
  echo "🔍 Found TODO comments to remove:"
  echo "$todos_to_remove" | while IFS=: read -r file line content; do
    echo "  $file:$line: ${content:0:80}..."
  done
  echo ""
  
  # Group by file and remove TODOs
  local files_modified=0
  echo "$todos_to_remove" | awk -F: '{print $1}' | sort -u | while read -r file; do
    if [[ ! -f "$file" ]]; then
      echo "⚠️  Skipping $file (file not found)"
      continue
    fi
    
    echo "📝 Processing $file..."
    
    # Create a backup
    local backup_file="${file}.todo_backup"
    cp "$file" "$backup_file"
    
    # Remove TODO comments (both standalone lines and inline comments)
    local removed_count=0
    local temp_file="${file}.tmp"
    
    while IFS= read -r line; do
      # Check if this line is a standalone TODO comment line (starts with comment)
      if echo "$line" | grep -qE '^\s*(\/\/|\/\*|#|\*)\s*TODO'; then
        removed_count=$((removed_count + 1))
        continue  # Skip this line entirely
      fi
      
      # Check for inline TODO comments (code followed by comment)
      # Pattern: anything followed by // TODO or /* TODO or # TODO
      if echo "$line" | grep -qE '(\/\/|\/\*|#).*TODO'; then
        # Remove the inline TODO comment
        # For //, remove everything from // TODO onwards
        # For /* TODO */, remove the comment block
        # For #, remove everything from # TODO onwards
        local cleaned_line
        cleaned_line=$(echo "$line" | sed -E 's/\s*(\/\/|#).*TODO.*$//' | sed -E 's/\s*\/\*.*TODO.*\*\///')
        # Only output if there's still content after removing the comment
        if [[ -n "$cleaned_line" && ! "$cleaned_line" =~ ^[[:space:]]*$ ]]; then
          echo "$cleaned_line"
          removed_count=$((removed_count + 1))
        else
          # The line was only a TODO comment, skip it
          removed_count=$((removed_count + 1))
          continue
        fi
      else
        # No TODO on this line, keep it as-is
        echo "$line"
      fi
    done < "$backup_file" > "$temp_file"
    
    if [[ $removed_count -gt 0 ]]; then
      mv "$temp_file" "$file"
      rm "$backup_file"
      echo "  ✅ Removed $removed_count TODO comment(s)"
      files_modified=$((files_modified + 1))
    else
      # No TODOs were removed
      rm "$temp_file"
      mv "$backup_file" "$file"
      echo "  ℹ️  No TODO comments to remove"
    fi
  done
  
  echo ""
  echo "✅ Processed TODO removals"
  echo "💡 Tip: Review the changes with 'jj diff' before committing"
}

# Manual PR approval with explicit PR number
alias stamp='f(){ gh pr review https://github.com/tensor-hq/vector-wallet/pull/$1 --approve; }; f'
