# New Task — Context Handoff

You are being asked to prepare a context handoff, similar to how plan mode works. Summarize the current conversation into a structured context document, then let the user decide what to do — all within this same session.

## Step 1: Generate Context Summary

Create a comprehensive context summary of this conversation. Structure it with ALL of the following sections (skip a section only if truly not applicable):

### 1. Current Work
Describe in detail what was being worked on. Pay special attention to the most recent messages and actions. Include what was accomplished and what state things are in right now.

### 2. Key Technical Concepts
List all important technical concepts, technologies, coding conventions, frameworks, and architectural decisions discussed. Include version numbers, configuration details, and any non-obvious technical context that would be needed to continue.

### 3. Relevant Files and Code
Enumerate specific files examined, modified, or created. Include:
- File paths with brief descriptions of changes
- Key code patterns or snippets that are central to the work
- Any configuration files or environment setup

### 4. Problem Solving
Document problems solved and any ongoing troubleshooting:
- What was tried and what worked/didn't work
- Root causes identified
- Workarounds applied

### 5. Pending Tasks and Next Steps
This is the MOST CRITICAL section. Be exhaustive:
- List ALL pending tasks explicitly requested by the user
- For each task, include the exact context of what was asked (use direct quotes from the conversation where possible)
- Describe exactly where work left off
- Include code snippets, file paths, and specific details needed to resume
- Note any blockers or dependencies

## Step 2: Save the Context

Before writing, check if `~/.claude/new-task-context.md` already exists using Bash: `test -f ~/.claude/new-task-context.md && echo EXISTS || echo NONE`.

- **If the file EXISTS**: Use AskUserQuestion to warn the user: "A previous context file already exists (from an earlier `/new-task` that was never resumed). Overwrite it?" with options "Yes, overwrite" and "No, cancel". If they cancel, stop here.
- **If the file does NOT exist** (or user chose to overwrite): Save the summary to `~/.claude/new-task-context.md` using the Write tool.

The file should start with:

```
# New Task Context
> Generated from previous Claude Code session
> Date: [current date]

[your context summary here]
```

## Step 3: Present Options

After saving, use AskUserQuestion to present exactly 3 options. These mirror plan mode's flow (clear context / keep context / keep editing):

**Question**: "Context saved to ~/.claude/new-task-context.md. How would you like to proceed?"

**Option 1 — "Yes, clear context"**:
Description: "Wipe conversation history and continue with just the summary (like plan mode). You'll be prompted to type /clear"

**Option 2 — "Yes, keep context"**:
Description: "Keep working in this conversation as-is. Context file saved for later if needed"

**Option 3 — "No, keep editing"**:
Description: "Revise the summary — type what to add, remove, or change"

## Handling Each Choice

### If "Yes, clear context"
This mimics plan mode's clearContext behavior within the same session:
1. Tell the user exactly this:

```
Type these two commands:
  1. /clear
  2. /resume-task
```

2. Explain this gives them a fresh context window with just the structured summary — exactly like plan mode's "clear context and auto-accept edits" but for continuing work instead of executing a plan. The `/resume-task` command automatically reads the saved context file and picks up where they left off.

### If "Yes, keep context"
Acknowledge the context file is saved at ~/.claude/new-task-context.md for later use, then resume the current conversation as normal. No action needed.

### If "No, keep editing"
Ask what changes they want, update the summary, save again to the same file, then re-present the same 3 options. Loop until they pick one of the "Yes" options.
