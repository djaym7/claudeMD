# Resume Task — Load Context from Previous Session

Read the context file at `~/.claude/new-task-context.md` and continue working from where the previous session left off.

## Instructions

1. Read the file `~/.claude/new-task-context.md` using the Read tool.
2. If the file doesn't exist or is empty, tell the user: "No saved context found. Run `/new-task` first to generate a context summary."
3. If the file exists, acknowledge what you've loaded by printing a brief summary:
   - What was being worked on (1-2 sentences)
   - What the immediate next steps are (bulleted list)
4. **Delete the context file** after successfully reading it, using Bash: `rm ~/.claude/new-task-context.md`. This prevents stale context from being resumed again and avoids accidental overwrites by future `/new-task` calls.
5. Then ask the user: "Ready to continue. What would you like to work on?"
