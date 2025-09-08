#!/usr/bin/env ts-node

import { execSync } from 'child_process';
import * as readline from 'readline';

// Action enum for type safety
enum InternalAction {
  ABANDON_LEFT = 'abandon_left',
  ABANDON_RIGHT = 'abandon_right',
  SQUASH_LEFT_INTO_RIGHT = 'squash_left_into_right',
  SQUASH_RIGHT_INTO_LEFT = 'squash_right_into_left',
  PRINT_STACK = 'print_stack',
  REFRESH = 'refresh',
  SHOW_INTERDIFF = 'show_interdiff',
  SHOW_DIFF_LEFT = 'show_diff_left',
  SHOW_DIFF_RIGHT = 'show_diff_right'
}

interface CommitInfo {
  changeId: string;
  commitId: string;
}

interface CliOptions {
  safe: boolean;
  auto: boolean;
}

/**
 * Parse command line arguments
 */
function parseCliArgs(): CliOptions {
  const args = process.argv.slice(2);
  return {
    safe: args.includes('--safe'),
    auto: args.includes('--auto')
  };
}

/**
 * Execute a jj command with optional safety confirmation
 */
async function executeJjCommand({
  rl,
  command,
  options,
  description
}: {
  rl: readline.Interface | null;
  command: string;
  options: CliOptions;
  description?: string;
}): Promise<string> {
  // Skip logging for common read-only commands
  const shouldLog = !command.startsWith('jj log') && 
                   !command.startsWith('jj op log') && 
                   !command.startsWith('jj diff') &&
                   !command.startsWith('jj interdiff') &&
                   command.trim() !== 'jj';
  
  if (shouldLog) {
    console.log(`💻 Executing: ${command}`);
  }
  
  if (options.safe && rl) {
    if (!rl) throw new Error('readline interface is required');
    const message = description 
      ? `${description}` 
      : `Execute command`;
    
    const confirmed = await askConfirmation(rl, message);
    if (confirmed === false) {
      throw new Error('Command execution cancelled by user');
    } else if (confirmed === 'skip') {
      console.log('⏭️  Command skipped');
      return ''; // Return empty string for skipped commands
    }
  }
  
  return execSync(command, { encoding: 'utf8' });
}

/**
 * Get list of divergent change IDs
 */
function getDivergentChangeIds(): string[] {
  const output = execSync(
    `jj log -T 'change_id ++ "\\n"' --no-graph --color=never | sort | uniq -d`,
    { encoding: 'utf8' }
  ) as string;
  return output.split('\n').map(s => s.trim()).filter(id => id.length > 0);
}

/**
 * Get commit info for given change IDs
 */
function getCommitInfoForChangeIds(changeIds: string[]): CommitInfo[] {
  const changeIdQuery = changeIds.map(id => `change_id("${id}")`).join(' | ');
  const command = `jj log -r '(${changeIdQuery}) ~ descendants((${changeIdQuery})+)' -T 'change_id ++ " " ++ commit_id ++ "\\n"' --no-graph --color=never`;
  
  const output = execSync(command, { encoding: 'utf8' });
  
  return output.split('\n').map(s => s.trim())
    .filter(line => line.length > 0)
    .map(line => {
      const [changeId, commitId] = line.split(' ');
      return { changeId, commitId };
    });
}

/**
 * Check if a commit is a merge commit by checking if it has multiple parents
 */
async function isMergeCommit({
  rl,
  commitId,
  options
}: {
  rl: readline.Interface | null;
  commitId: string;
  options: CliOptions;
}): Promise<boolean> {
  const command = `jj log -r ${commitId}- -T 'change_id ++ "\\n"' --no-graph`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: `Check if commit ${commitId} is a merge commit`
  });
  // If there are multiple lines (multiple parents), it's a merge commit
  const parents = output.trim().split('\n').filter(line => line.length > 0);
  return parents.length > 1;
}

/**
 * Check if a commit contains conflicts using jj's built-in conflict detection
 */
async function checkForConflicts({
  rl,
  commitId,
  options
}: {
  rl: readline.Interface | null;
  commitId: string;
  options: CliOptions;
}): Promise<boolean> {
  const command = `jj log -r "${commitId} & conflicts()" --no-graph`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: `Check commit ${commitId} for conflicts`
  });
  // If output is non-empty, the commit has conflicts
  return output.trim().length > 0;
}

/**
 * Get the first commit ID for a change ID
 */
async function getFirstCommitForChangeId({
  rl,
  changeId,
  options
}: {
  rl: readline.Interface | null;
  changeId: string;
  options: CliOptions;
}): Promise<string | null> {
  const command = `jj log -r 'change_id("${changeId}")' -T 'commit_id ++ "\\n"' --no-graph --color=never`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: `Get commits for change ID ${changeId}`
  });
  const commitIds = output.trim().split('\n').filter(id => id.length > 0);
  return commitIds.length > 0 ? commitIds[0] : null;
}

/**
 * Get commit description
 */
async function getCommitDescription({
  rl,
  commitId,
  options
}: {
  rl: readline.Interface | null;
  commitId: string;
  options: CliOptions;
}): Promise<string> {
  const command = `jj log -r ${commitId} -T "description" --no-graph`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: `Get description for commit ${commitId}`
  });
  return output.trim();
}

/**
 * Display interdiff between two commits
 */
async function showInterdiff({
  rl,
  fromCommitId,
  toCommitId,
  options
}: {
  rl: readline.Interface | null;
  fromCommitId: string;
  toCommitId: string;
  options: CliOptions;
}): Promise<{ output: string; isEmpty: boolean }> {
  const toolFlag = options.auto ? ' --tool=:git' : '';
  const command = `jj interdiff --from ${fromCommitId} --to ${toCommitId}${toolFlag}`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: 'Show differences between commits'
  });
  console.log(output);
  
  const isEmpty = output.trim().length === 0;
  return { output, isEmpty };
}

/**
 * Print the current operation ID
 */
async function printCurrentOperationId({
  rl,
  options
}: {
  rl: readline.Interface | null;
  options: CliOptions;
}): Promise<void> {
  const command = `jj op log -n 1`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: 'Show current operation log'
  });
  console.log('Current operation:');
  console.log(output);
}


/**
 * Show diff of a single commit
 */
async function showCommitDiff({
  rl,
  commitId,
  options
}: {
  rl: readline.Interface | null;
  commitId: string;
  options: CliOptions;
}): Promise<void> {
  const command = `jj diff -r ${commitId}`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: `Show diff of commit ${commitId}`
  });
  console.log(`\n📝 Diff of commit ${commitId}:`);
  console.log(output);
}

/**
 * Print the stack
 */
async function printStack({
  rl,
  options
}: {
  rl: readline.Interface | null;
  options: CliOptions;
}): Promise<void> {
  const command = `jj`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description: 'Show commit stack'
  });
  console.log(output);
}


/**
 * Rebase sequence of commits onto destination commit
 */
async function rebaseSequence({
  rl,
  sequenceRoot,
  destination,
  options
}: {
  rl: readline.Interface | null;
  sequenceRoot: string;
  destination: string;
  options: CliOptions;
}): Promise<void> {
  try {
    const command = `jj rebase -s "${sequenceRoot}+" -d "${destination}"`;
    const description = `Rebase commit sequence ${sequenceRoot} onto ${destination}`;
    const output = await executeJjCommand({
      rl,
      command,
      options,
      description
    });
    if (output.trim()) {
      console.log(output);
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (errorMessage.includes('Empty revision set')) {
      console.log('ℹ️  No commits to rebase (empty revision set) - continuing...');
      return; // Ignore this error and continue
    }
    throw new Error(`Failed to rebase: ${error}`);
  }
}

/**
 * Abandon a commit
 */
async function abandonCommit({
  rl,
  commitId,
  options
}: {
  rl: readline.Interface | null;
  commitId: string;
  options: CliOptions;
}): Promise<void> {
  const command = `jj abandon -r ${commitId}`;
  const description = `Abandon commit ${commitId}`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description
  });
  if (output.trim()) {
    console.log(output);
  }
}

/**
 * Squash one commit into another
 */
async function squashCommit({
  rl,
  fromCommitId,
  intoCommitId,
  options
}: {
  rl: readline.Interface | null;
  fromCommitId: string;
  intoCommitId: string;
  options: CliOptions;
}): Promise<void> {
  const command = `jj squash -u --from ${fromCommitId} --into ${intoCommitId}`;
  const description = `Squash commit ${fromCommitId} into ${intoCommitId}`;
  const output = await executeJjCommand({
    rl,
    command,
    options,
    description
  });
  if (output.trim()) {
    console.log(output);
  }
}

/**
 * Ask user for confirmation with skip option
 * Returns: true = yes, false = no, 'skip' = skip this command
 */
function askConfirmation(rl: readline.Interface, message: string): Promise<boolean | 'skip'> {
  return new Promise((resolve) => {
    rl.question(`${message} (y/N/s): `, (answer) => {
      const lower = answer.toLowerCase();
      if (lower === 'y' || lower === 'yes') {
        resolve(true);
      } else if (lower === 's' || lower === 'skip') {
        resolve('skip');
      } else {
        resolve(false);
      }
    });
  });
}

/**
 * Let user choose a change ID from multiple options
 */
async function chooseChangeId({
  rl,
  changeIds,
  options
}: {
  rl: readline.Interface;
  changeIds: string[];
  options: CliOptions;
}): Promise<string | null> {
  console.log('\n📋 Multiple change IDs found. Please choose which one to work on:');
  
  // Get first commit and description for each change ID
  const changeOptions: Array<{ changeId: string; commitId: string; description: string }> = [];
  
  for (let i = 0; i < changeIds.length; i++) {
    const changeId = changeIds[i];
    const commitId = await getFirstCommitForChangeId({ rl, changeId, options });
    
    if (commitId) {
      const description = await getCommitDescription({ rl, commitId, options });
      changeOptions.push({ changeId, commitId, description });
      console.log(`${i + 1}. ${commitId} - ${description}`);
    } else {
      console.log(`${i + 1}. ${changeId} - [Failed to get commit info]`);
      changeOptions.push({ changeId, commitId: '', description: '[Failed to get commit info]' });
    }
  }
  
  // In auto mode, automatically choose the first option
  if (options.auto) {
    console.log('\n🤖 Auto mode: Automatically choosing option 1 (first change ID)');
    return changeIds[0];
  }
  
  return new Promise((resolve) => {
    rl.question(`\nChoose option (1-${changeIds.length}) or 'q' to quit: `, (answer) => {
      if (answer.toLowerCase() === 'q') {
        resolve(null);
        return;
      }
      
      const choice = parseInt(answer);
      if (choice >= 1 && choice <= changeIds.length) {
        resolve(changeIds[choice - 1]);
      } else {
        console.log('Invalid choice.');
        resolve(null);
      }
    });
  });
}

/**
 * Show menu and get user choice
 */
function showMenu(rl: readline.Interface): Promise<string> {
  return new Promise((resolve) => {
    console.log('\nWhat would you like to do?');
    console.log('AL. Abandon left');
    console.log('AR. Abandon right');
    console.log('SL. Squash left into right');
    console.log('SR. Squash right into left');
    console.log('P. Print stack');
    console.log('R. Refresh (restart from beginning)');
    console.log('I. Show interdiff');
    console.log('DL. Show diff of left commit');
    console.log('DR. Show diff of right commit');
    
    rl.question('Choose an option: ', (answer) => {
      resolve(answer.toUpperCase());
    });
  });
}

/**
 * Normalize action input to internal action enum
 */
function normalizeAction(action: string | InternalAction): InternalAction {
  // If it's already an InternalAction, return it directly
  if (Object.values(InternalAction).includes(action as InternalAction)) {
    return action as InternalAction;
  }
  
  // Handle string input
  const upperAction = action.toUpperCase();
  
  switch (upperAction) {
    case 'AL':
      return InternalAction.ABANDON_LEFT;
    case 'AR':
      return InternalAction.ABANDON_RIGHT;
    case 'SL':
      return InternalAction.SQUASH_LEFT_INTO_RIGHT;
    case 'SR':
      return InternalAction.SQUASH_RIGHT_INTO_LEFT;
    case 'P':
      return InternalAction.PRINT_STACK;
    case 'R':
      return InternalAction.REFRESH;
    case 'I':
      return InternalAction.SHOW_INTERDIFF;
    case 'DL':
      return InternalAction.SHOW_DIFF_LEFT;
    case 'DR':
      return InternalAction.SHOW_DIFF_RIGHT;
    default:
      throw new Error(`Invalid action: ${action}`);
  }
}

/**
 * Handle user action
 * Returns: true = completed, false = continue, 'restart' = restart from beginning
 */
async function handleAction({
  rl,
  action,
  commitIdLeft,
  commitIdRight,
  options
}: {
  rl: readline.Interface;
  action: string;
  commitIdLeft: string;
  commitIdRight: string;
  options: CliOptions;
}): Promise<boolean | 'restart'> {
  // Normalize action to internal action enum
  const normalizedAction = normalizeAction(action);
  
  switch (normalizedAction) {
    case InternalAction.ABANDON_LEFT:
      const confirmAbandonLeft = options.safe ? await askConfirmation(rl, `Abandon left commit (${commitIdLeft})?`) : true;
      if (confirmAbandonLeft) {
        await printCurrentOperationId({ rl, options });
        await rebaseSequence({ rl, sequenceRoot: commitIdLeft, destination: commitIdRight, options });
        await abandonCommit({ rl, commitId: commitIdLeft, options });
        console.log('\nUpdated stack:');
        await printStack({ rl, options });
        console.log('\n🔄 Restarting from beginning due to state changes...');
        return 'restart';
      }
      break;

    case InternalAction.ABANDON_RIGHT:
      const confirmAbandonRight = options.safe ? await askConfirmation(rl, `Abandon right commit (${commitIdRight})?`) : true;
      if (confirmAbandonRight) {
        await printCurrentOperationId({ rl, options });
        await rebaseSequence({ rl, sequenceRoot: commitIdRight, destination: commitIdLeft, options });
        await abandonCommit({ rl, commitId: commitIdRight, options });
        console.log('\nUpdated stack:');
        await printStack({ rl, options });
        console.log('\n🔄 Restarting from beginning due to state changes...');
        return 'restart';
      }
      break;

    case InternalAction.SQUASH_LEFT_INTO_RIGHT:
      const confirmSquashLeft = options.safe ? await askConfirmation(rl, `Squash left commit (${commitIdLeft}) into right (${commitIdRight})?`) : true;
      if (confirmSquashLeft) {
        await printCurrentOperationId({ rl, options });
        await rebaseSequence({ rl, sequenceRoot: commitIdLeft, destination: commitIdRight, options });
        await squashCommit({ rl, fromCommitId: commitIdLeft, intoCommitId: commitIdRight, options });
        console.log('\nUpdated stack:');
        await printStack({ rl, options });
        console.log('\n🔄 Restarting from beginning due to state changes...');
        return 'restart';
      }
      break;

    case InternalAction.SQUASH_RIGHT_INTO_LEFT:
      const confirmSquashRight = options.safe ? await askConfirmation(rl, `Squash right commit (${commitIdRight}) into left (${commitIdLeft})?`) : true;
      if (confirmSquashRight) {
        await printCurrentOperationId({ rl, options });
        await rebaseSequence({ rl, sequenceRoot: commitIdRight, destination: commitIdLeft, options });
        await squashCommit({ rl, fromCommitId: commitIdRight, intoCommitId: commitIdLeft, options });
        console.log('\nUpdated stack:');
        await printStack({ rl, options });
        console.log('\n🔄 Restarting from beginning due to state changes...');
        return 'restart';
      }
      break;

    case InternalAction.PRINT_STACK:
      await printStack({ rl, options });
      break;

    case InternalAction.REFRESH:
      console.log('\n🔄 Refreshing state...');
      return 'restart';

    case InternalAction.SHOW_INTERDIFF:
      const interdiffResult = await showInterdiff({ 
        rl, 
        fromCommitId: commitIdLeft, 
        toCommitId: commitIdRight, 
        options: { ...options, auto: false } 
      });
      console.log('\n🔄 Interdiff:');
      console.log(interdiffResult.output);
      break;

    case InternalAction.SHOW_DIFF_LEFT:
      await showCommitDiff({ rl, commitId: commitIdLeft, options });
      break;

    case InternalAction.SHOW_DIFF_RIGHT:
      await showCommitDiff({ rl, commitId: commitIdRight, options });
      break;

    default:
      // Exhaustive check - this should never be reached
      const _exhaustiveCheck: never = normalizedAction;
      throw new Error(`Unhandled internal action: ${normalizedAction}`);
  }
  
  return false;
}

/**
 * Show help message
 */
function showHelp(): void {
  console.log(`
JJ Divergent Commit Resolver

Usage: jj_divergent_resolver.ts [options]

Options:
  --safe    Ask for confirmation before running any jj command
  --auto    Use git tool for interdiff and auto-squash if empty
  --help    Show this help message

Interactive Commands:
  AL        Abandon left commit
  AR        Abandon right commit  
  SL        Squash left commit into right
  SR        Squash right commit into left
  P         Print current stack
  R         Refresh (restart from beginning)
  I         Show interdiff (without tool option)
  DL        Show diff of left commit
  DR        Show diff of right commit

Safe Mode Confirmations (when using --safe):
  y/yes     Execute the command
  n/no      Cancel and exit
  s/skip    Skip this command and continue

Examples:
  ./jj_divergent_resolver.ts
  ./jj_divergent_resolver.ts --safe
  ./jj_divergent_resolver.ts --auto
  ./jj_divergent_resolver.ts --safe --auto

Auto Mode Features:
  - Adds --tool=:git to interdiff commands for better diff display
  - Automatically performs "Squash left into right" if interdiff is empty
  - Still shows conflict warnings and safety checks

Note: After any rebase or squash operation, the tool automatically restarts
from the beginning to ensure fresh state, as commit IDs may have changed.
`);
}

/**
 * Process divergent commits - main logic that can be restarted
 */
async function processDivergentCommits(rl: readline.Interface, options: CliOptions): Promise<boolean> {
  console.log('🔍 Checking for divergent commits...');
  
  // Get divergent change IDs
  const divergentChangeIds = getDivergentChangeIds();
  
  if (divergentChangeIds.length === 0) {
    console.log('✅ No divergent commits found.');
    return true; // Exit successfully
  }

  console.log(`Found ${divergentChangeIds.length} divergent change IDs:`, divergentChangeIds);

  // Get commit info for divergent change IDs
  const commitInfos = getCommitInfoForChangeIds(divergentChangeIds);
  
  if (commitInfos.length > 2) {
    console.log('\n⚠️  More than 2 commits found for divergent change IDs.');
    console.log('You must choose a specific change ID to work on.');
    
    // Let user choose which change ID to work with
    const chosenChangeId = await chooseChangeId({ rl, changeIds: Array.from(new Set(commitInfos.map(info => info.changeId))), options });
    
    if (!chosenChangeId) {
      console.log('No change ID selected. Exiting.');
      return true; // Exit
    }
    
    // Filter to only the chosen change ID and restart
    console.log(`\n🎯 Working with change ID: ${chosenChangeId}`);
    const filteredChangeIds = [chosenChangeId];
    const filteredCommitInfos = getCommitInfoForChangeIds(filteredChangeIds);
    
    if (filteredCommitInfos.length < 2) {
      console.error('❌ Error: Selected change ID has less than 2 commits. Cannot proceed.');
      return true; // Exit with error
    }
    
    // Continue with the filtered commit infos
    const newCommitInfos = filteredCommitInfos;
    return await processSelectedCommits(rl, newCommitInfos, options);
  }

  // Process the commits normally
  return await processSelectedCommits(rl, commitInfos, options);
}

/**
 * Process selected commits (extracted logic for reuse)
 */
async function processSelectedCommits(
  rl: readline.Interface, 
  commitInfos: CommitInfo[], 
  options: CliOptions
): Promise<boolean> {
  if (commitInfos.length < 2) {
    console.error('❌ Error: Less than 2 commits found. Cannot proceed.');
    return true; // Exit with error
  }

  const commitIdLeft = commitInfos[0].commitId;
  const commitIdRight = commitInfos[1].commitId;

  console.log(`\n📊 Commit comparison:`);
  console.log(`Left:  ${commitInfos[0].changeId} ${commitIdLeft}`);
  console.log(`Right: ${commitInfos[1].changeId} ${commitIdRight}`);

  // Get and display commit descriptions
  console.log('\n📝 Commit descriptions:');
  const leftDescription = await getCommitDescription({ rl, commitId: commitIdLeft, options });
  const rightDescription = await getCommitDescription({ rl, commitId: commitIdRight, options });
  console.log(`Left:  ${leftDescription}`);
  console.log(`Right: ${rightDescription}`);

  // Check for conflicts and merge commits
  console.log('\n🔍 Checking for conflicts and merge commits...');
  const leftHasConflicts = await checkForConflicts({ rl, commitId: commitIdLeft, options });
  const rightHasConflicts = await checkForConflicts({ rl, commitId: commitIdRight, options });
  const leftIsMerge = await isMergeCommit({ rl, commitId: commitIdLeft, options });
  const rightIsMerge = await isMergeCommit({ rl, commitId: commitIdRight, options });
  
  const hasConflicts = leftHasConflicts || rightHasConflicts;
  const hasMergeCommits = leftIsMerge || rightIsMerge;
  const hasIssues = hasConflicts || hasMergeCommits;
  
  if (hasIssues) {
    console.log('🚨 WARNING: Issues detected with one or more commits');
    console.log('🚨 Squashing these commits may not be recommended');
    
    if (leftHasConflicts) console.log(`   - Left commit (${commitIdLeft}) has conflict markers`);
    if (rightHasConflicts) console.log(`   - Right commit (${commitIdRight}) has conflict markers`);
    if (leftIsMerge) console.log(`   - Left commit (${commitIdLeft}) is a merge commit`);
    if (rightIsMerge) console.log(`   - Right commit (${commitIdRight}) is a merge commit`);
    
    if (leftHasConflicts || rightHasConflicts) {
      console.log('🚨 Commits with conflict markers indicate unresolved merge conflicts');
    }
    if (leftIsMerge || rightIsMerge) {
      console.log('🚨 Merge commits may contain important merge resolution history');
    }
    console.log('');
  }

  // Show interdiff
  console.log('\n🔄 Interdiff:');
  const interdiffResult = await showInterdiff({ rl, fromCommitId: commitIdLeft, toCommitId: commitIdRight, options });

  // Auto mode: if interdiff is empty, choose action based on detected issues
  if (options.auto && interdiffResult.isEmpty) {
    let autoAction: InternalAction | null = null;
    
    if (!hasIssues) {
      // No issues detected - safe to squash
      console.log('🤖 Auto mode: Interdiff is empty and no issues detected, automatically squashing left into right...');
      autoAction = InternalAction.SQUASH_LEFT_INTO_RIGHT;
    } else if (hasConflicts && !hasMergeCommits) {
      // Conflict markers detected but no merge commits - abandon left
      console.log('🤖 Auto mode: Interdiff is empty but conflict markers detected, automatically abandoning left commit...');
      autoAction = InternalAction.ABANDON_LEFT;
    } else {
      // Merge commits or other complex issues - switch to manual mode
      console.log('🤖 Auto mode: Interdiff is empty but merge commits detected - switching to manual mode');
      console.log('🛡️  Please review the warnings above and choose an action manually');
    }
    
    if (autoAction) {
      // Execute the automatic action using the existing action handler
      const result = await handleAction({ 
        rl, 
        action: autoAction, 
        commitIdLeft, 
        commitIdRight, 
        options: { ...options, safe: false } // Disable confirmation for auto actions
      });
      
      if (result === 'restart') {
        return false; // Signal restart needed
      }
      // If action completed successfully, it should have restarted already
      throw new Error('Unexpected: Auto action should have triggered restart');
    }
  }

  // Interactive menu loop
  while (true) {
    const action = await showMenu(rl);
    const result = await handleAction({ rl, action, commitIdLeft, commitIdRight, options });
    
    if (result === true) {
      return true; // Exit successfully
    } else if (result === 'restart') {
      return false; // Signal restart needed
    }
    // Continue loop if result === false
  }
}

/**
 * Main execution function
 */
async function main(): Promise<void> {
  const options = parseCliArgs();
  
  // Handle help flag
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    showHelp();
    return;
  }

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  try {
    if (options.safe) {
      console.log('🔒 Safe mode enabled - will ask for confirmation before each jj command');
    }
    if (options.auto) {
      console.log('🤖 Auto mode enabled - will use git tool for interdiff and auto-squash if empty');
    }

    // Main processing loop - restart when needed
    while (true) {
      const shouldExit = await processDivergentCommits(rl, options);
      if (shouldExit) {
        break; // Exit the main loop
      }
      // Otherwise restart from the beginning
    }

  } catch (error) {
    console.error('❌ Error:', error instanceof Error ? error.message : error);
  } finally {
    rl.close();
  }
}

// Entry point
if (require.main === module) {
  main().catch(console.error);
}