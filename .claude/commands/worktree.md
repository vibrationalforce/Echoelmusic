# Worktree — Parallel Development with Git Worktrees

Manage parallel Claude Code sessions using Git worktrees. Based on Matt Pocock's pattern for massive throughput increases — multiple Claude instances shipping independently on the same repo.

## What Are Worktrees?

Git worktrees create isolated copies of your repo sharing the same `.git` directory. Each worktree has its own working directory and branch — perfect for running parallel Claude Code sessions without file conflicts.

## Commands

### Create a new worktree
```bash
FEATURE="$1"  # e.g., "fix-audio-latency"
git worktree add ../$FEATURE -b claude/$FEATURE
echo "Created worktree at ../$FEATURE on branch claude/$FEATURE"
echo "Start Claude Code there: cd ../$FEATURE && claude"
```

### List active worktrees
```bash
git worktree list
```

### Remove a worktree (after merging)
```bash
FEATURE="$1"
git worktree remove ../$FEATURE
git branch -d claude/$FEATURE 2>/dev/null
echo "Removed worktree and branch for $FEATURE"
```

### Cherry-pick from worktree into current branch
```bash
FEATURE="$1"
COMMITS=$(git log claude/$FEATURE --oneline --not HEAD | head -20)
echo "Commits on claude/$FEATURE:"
echo "$COMMITS"
echo ""
echo "Cherry-pick all: git cherry-pick claude/$FEATURE~N..claude/$FEATURE"
```

## Parallel Development Pattern

```
Main Repo (you are here)
├── ../fix-audio-latency/     ← Claude session 1: fixing DSP
├── ../add-bio-mapping/       ← Claude session 2: new bio feature
├── ../refactor-mixer/        ← Claude session 3: mixer cleanup
└── All share same .git       ← No duplication, instant creation
```

### Workflow:
1. **Create worktrees** for independent tasks
2. **Launch Claude Code** in each worktree (`cd ../feature && claude`)
3. **Each session works independently** — no file conflicts
4. **Cherry-pick completed work** into your integration branch
5. **Remove worktrees** after merging

## Claude Code Integration

Claude Code natively supports worktrees via the `--worktree` / `-w` flag:
```bash
claude --worktree  # Creates isolated worktree automatically
```

The Agent tool also supports `isolation: "worktree"` for subagents:
- Subagent gets its own copy of the repo
- Changes are returned on a separate branch
- Main context stays clean

## Best Practices

- **One task per worktree** — matches Ralph Wiggum Lambda (one fix per cycle)
- **Independent tasks only** — don't create worktrees for tasks that depend on each other
- **Clean up after merging** — `git worktree prune` removes stale entries
- **Use for big parallel audits** — 3 agents (Core, UI, Domain) each in their own worktree
- **Commit frequently** in each worktree — easier to cherry-pick specific commits

## Echoelmusic-Specific Usage

Good candidates for parallel worktrees:
- Audio engine work + UI work (fully independent)
- Bio-signal processing + Visual rendering (separate pipelines)
- Test writing + Documentation (no code overlap)
- Platform-specific fixes (iOS guard fixes + Android Kotlin work)

Bad candidates (do sequentially):
- Wiring changes that affect multiple engines
- EchoelCreativeWorkspace hub modifications
- Shared type/protocol changes
