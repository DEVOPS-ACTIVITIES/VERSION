#!/bin/sh
set -e

echo "=========================================="
echo "Starting automatic hotfix sync process"
echo "Source: feat"
echo "Targets: $TARGET_BRANCHES"
echo "=========================================="

FAILED_BRANCHES=""
CONFLICT_BRANCHES=""
HAS_CONFLICTS=false

for branch in $TARGET_BRANCHES; do
  echo ""
  echo "------------------------------------------------"
  echo "Processing branch: $branch"
  echo "------------------------------------------------"

  # Check if branch exists on remote
  if ! git ls-remote --heads origin $branch | grep -q "refs/heads/$branch$"; then
    echo "⚠️  Skip: Branch '$branch' does not exist on remote"
    continue
  fi

  # Checkout the target branch
  if git checkout -B "$branch" "origin/$branch"; then
    echo "✓ Checked out $branch"

    # First, try merge without auto-resolution to detect conflicts
    echo "Attempting merge to detect conflicts..."
    if git merge "origin/feat" --no-commit --no-ff 2>&1; then
      echo "✓ No conflicts detected"
      # Complete the merge
      git commit --no-edit -m "Merge feat into $branch"

      # Push changes (pipeline will be triggered on target branch for validation/deployment)
      if git push origin "$branch"; then
        echo "✅ Successfully synced $branch with feat - pipeline triggered on $branch"
      else
        echo "❌ Failed to push $branch"
        FAILED_BRANCHES="$FAILED_BRANCHES $branch"
      fi
    else
      echo "⚠️  Conflicts detected on $branch"
      HAS_CONFLICTS=true
      CONFLICT_BRANCHES="$CONFLICT_BRANCHES $branch"

      # Display conflict details to console
      CONFLICT_COUNT=$(git diff --name-only --diff-filter=U | wc -l)
      echo "Total files with conflicts: $CONFLICT_COUNT"
      echo "Conflicted files:"
      git diff --name-only --diff-filter=U

      # Abort the conflicted merge
      git merge --abort
      echo "Auto-resolving conflicts using '-X theirs' strategy..."
      if git merge "origin/feat" --no-edit -X theirs; then
        echo "✓ Merged feat into $branch (conflicts auto-resolved)"

        # Push changes (trigger pipeline so the resolved branch is validated)
        if git push origin "$branch"; then
          echo "⚠️  Successfully synced $branch with feat (with auto-resolved conflicts) - pipeline triggered"
        else
          echo "❌ Failed to push $branch"
          FAILED_BRANCHES="$FAILED_BRANCHES $branch"
        fi
      else
        echo "❌ Merge failed even with -X theirs on $branch"
        git merge --abort
        FAILED_BRANCHES="$FAILED_BRANCHES $branch"
      fi
    fi
  else
    echo "❌ Failed to checkout $branch"
    FAILED_BRANCHES="$FAILED_BRANCHES $branch"
  fi
done

echo ""
echo "=========================================="
echo "Sync process completed"
echo "=========================================="

# Print summary to console
if [ "$HAS_CONFLICTS" = true ]; then
  echo "STATUS: ⚠️  CONFLICTS AUTO-RESOLVED"
  echo ""
  echo "Branches with conflicts:$CONFLICT_BRANCHES"
  echo ""
fi

if [ -n "$FAILED_BRANCHES" ]; then
  echo "STATUS: ❌ SOME BRANCHES FAILED"
  echo ""
  echo "Failed branches:$FAILED_BRANCHES"
  echo ""
fi

if [ "$HAS_CONFLICTS" = false ] && [ -z "$FAILED_BRANCHES" ]; then
  echo "STATUS: ✅ ALL SYNCED SUCCESSFULLY"
  echo ""
  echo "No conflicts were detected."
  echo "All branches are up to date with feat."
  echo ""
fi

echo "============================================="
if [ -n "$FAILED_BRANCHES" ]; then
  echo "⚠️  Branches that failed to sync:$FAILED_BRANCHES"
  echo "Please review and sync these branches manually"
  exit 0
elif [ "$HAS_CONFLICTS" = true ]; then
  echo "⚠️  Job completed with conflicts (auto-resolved)"
  # Exit with code 1 to mark as warning (allow_failure will prevent pipeline failure)
  exit 1
else
  echo "✅ All branches synced successfully without conflicts"
fi
