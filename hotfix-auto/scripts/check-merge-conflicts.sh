#!/bin/sh
set -e

# Helper: escape special HTML characters in a string
html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

GENERATED_AT="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
REPORT_SUMMARY="conflict-reports/summary.html"

# Begin summary HTML
cat > "$REPORT_SUMMARY" <<'HTML_HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Merge Conflict Check Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 32px; background: #f9f9f9; color: #222; }
    h1 { color: #c0392b; }
    table { border-collapse: collapse; width: 100%; margin-top: 16px; }
    th, td { border: 1px solid #ccc; padding: 8px 14px; text-align: left; }
    th { background: #333; color: #fff; }
    tr.ok { background: #eaffea; }
    tr.conflict { background: #fff3cd; }
    tr.skipped { background: #f0f0f0; color: #777; }
    tr.error { background: #fde; }
    .badge-ok { color: #27ae60; font-weight: bold; }
    .badge-conflict { color: #e67e22; font-weight: bold; }
    .badge-skipped { color: #888; }
    .badge-error { color: #c0392b; font-weight: bold; }
    .meta { font-size: 0.9em; color: #555; margin-bottom: 12px; }
    a { color: #2980b9; }
  </style>
</head>
<body>
<h1>Merge Conflict Check Report</h1>
HTML_HEADER

# Append dynamic meta (printf used to safely embed shell variables)
printf '<p class="meta"><strong>Source branch:</strong> %s<br>\n' "$(html_escape "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME")" >> "$REPORT_SUMMARY"
printf '<strong>Target branches:</strong> %s<br>\n' "$(html_escape "$TARGET_BRANCHES")" >> "$REPORT_SUMMARY"
printf '<strong>Pipeline:</strong> <a href="%s">%s</a><br>\n' "$(html_escape "$CI_PIPELINE_URL")" "$(html_escape "$CI_PIPELINE_URL")" >> "$REPORT_SUMMARY"
printf '<strong>Generated at:</strong> %s</p>\n' "$GENERATED_AT" >> "$REPORT_SUMMARY"
echo '<table>' >> "$REPORT_SUMMARY"
echo '<tr><th>Branch</th><th>Status</th><th>Details</th></tr>' >> "$REPORT_SUMMARY"

echo "=========================================="
echo "Pre-merge conflict check (dry-run)"
echo "Source branch: $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME"
echo "Targets: $TARGET_BRANCHES"
echo "=========================================="

CONFLICT_BRANCHES=""
HAS_CONFLICTS=false

for branch in $TARGET_BRANCHES; do
  echo ""
  echo "------------------------------------------------"
  echo "Checking branch: $branch"
  echo "------------------------------------------------"

  # Check if branch exists on remote
  if ! git ls-remote --heads origin $branch | grep -q "refs/heads/$branch$"; then
    echo "⚠️  Skip: Branch '$branch' does not exist on remote"
    printf '<tr class="skipped"><td>%s</td><td><span class="badge-skipped">SKIPPED</span></td><td>Branch does not exist on remote</td></tr>\n' "$(html_escape "$branch")" >> "$REPORT_SUMMARY"
    continue
  fi

  # Checkout the target branch in a temporary workspace
  if git checkout -B "$branch" "origin/$branch"; then
    echo "✓ Checked out $branch"
    # Dry-run merge to detect conflicts (no commit, no push)
    if git merge "origin/$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME" --no-commit --no-ff; then
      echo "✅ No conflicts detected for $branch"
      printf '<tr class="ok"><td>%s</td><td><span class="badge-ok">OK</span></td><td>No conflicts</td></tr>\n' "$(html_escape "$branch")" >> "$REPORT_SUMMARY"
      # Abort the pending merge (we only wanted to check, not actually merge)
      git merge --abort 2>/dev/null || true
    else
      echo "⚠️  Conflicts detected on $branch"
      HAS_CONFLICTS=true
      CONFLICT_BRANCHES="$CONFLICT_BRANCHES $branch"

      # Collect ALL conflicted files reliably via the index unmerged entries
      CONFLICTED_FILES=$(git ls-files --unmerged | cut -f 2 | sort -u)
      CONFLICT_COUNT=$(echo "$CONFLICTED_FILES" | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')
      echo "Total files with conflicts: $CONFLICT_COUNT"
      echo "Conflicted files:"
      echo "$CONFLICTED_FILES"

      # Row in summary table with link to per-branch report
      BRANCH_HTML_FILE="conflicts-${branch}.html"
      printf '<tr class="conflict"><td>%s</td><td><span class="badge-conflict">CONFLICT</span></td><td>%s file(s) — <a href="%s">view report</a></td></tr>\n' \
        "$(html_escape "$branch")" "$CONFLICT_COUNT" "$(html_escape "$BRANCH_HTML_FILE")" >> "$REPORT_SUMMARY"

      # ---- Per-branch HTML report ----
      BRANCH_REPORT="conflict-reports/${BRANCH_HTML_FILE}"
      cat > "$BRANCH_REPORT" <<'BRANCH_HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; margin: 32px; background: #f9f9f9; color: #222; }
    h1 { color: #c0392b; }
    h2 { color: #555; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
    .meta { font-size: 0.9em; color: #555; margin-bottom: 16px; }
    ul { margin: 8px 0 16px 24px; }
    pre { background: #1e1e1e; color: #d4d4d4; padding: 16px; border-radius: 6px; overflow-x: auto;
          font-size: 0.85em; line-height: 1.5; white-space: pre-wrap; overflow-wrap: break-word; }
    .marker-ours   { color: #4ec9b0; font-weight: bold; }
    .marker-sep    { color: #9cdcfe; font-weight: bold; }
    .marker-theirs { color: #ce9178; font-weight: bold; }
  </style>
</head>
<body>
BRANCH_HEADER

      printf '<h1>Conflict Report: %s</h1>\n' "$(html_escape "$branch")" >> "$BRANCH_REPORT"
      printf '<p class="meta"><strong>Source branch:</strong> %s<br><strong>Target branch:</strong> %s<br><strong>Conflicted files:</strong> %s</p>\n' \
        "$(html_escape "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME")" "$(html_escape "$branch")" "$CONFLICT_COUNT" >> "$BRANCH_REPORT"
      echo '<h2>Conflicted Files</h2><ul>' >> "$BRANCH_REPORT"
      echo "$CONFLICTED_FILES" | while IFS= read -r cfile; do
        [ -z "$cfile" ] && continue
        printf '  <li>%s</li>\n' "$(html_escape "$cfile")" >> "$BRANCH_REPORT"
      done
      echo '</ul>' >> "$BRANCH_REPORT"
      echo '<h2>Conflict Details</h2>' >> "$BRANCH_REPORT"

      # Write each conflicted file's content with conflict markers
      echo "$CONFLICTED_FILES" | while IFS= read -r cfile; do
        [ -z "$cfile" ] && continue
        printf '<h3>%s</h3>\n' "$(html_escape "$cfile")" >> "$BRANCH_REPORT"
        echo '<pre>' >> "$BRANCH_REPORT"
        if [ -f "$cfile" ]; then
          # Escape HTML, then highlight conflict marker lines
          html_escape "$(cat "$cfile")" | sed \
            's|^\(&lt;&lt;&lt;&lt;&lt;&lt;&lt;.*\)|<span class="marker-ours">\1</span>|;
             s|^\(=======\)|<span class="marker-sep">\1</span>|;
             s|^\(&gt;&gt;&gt;&gt;&gt;&gt;&gt;.*\)|<span class="marker-theirs">\1</span>|' \
            >> "$BRANCH_REPORT"
        else
          echo '(unable to read file content)' >> "$BRANCH_REPORT"
        fi
        echo '</pre>' >> "$BRANCH_REPORT"
      done
      printf '</body></html>\n' >> "$BRANCH_REPORT"
      git merge --abort
    fi
  else
    echo "❌ Failed to checkout $branch"
    printf '<tr class="error"><td>%s</td><td><span class="badge-error">ERROR</span></td><td>Failed to checkout branch</td></tr>\n' "$(html_escape "$branch")" >> "$REPORT_SUMMARY"
  fi
done

echo '</table>' >> "$REPORT_SUMMARY"
echo "" >> "$REPORT_SUMMARY"

if [ "$HAS_CONFLICTS" = true ]; then
  printf '<p><strong>Result:</strong> &#9888; Conflicts found in: %s</p>\n' "$(html_escape "$CONFLICT_BRANCHES")" >> "$REPORT_SUMMARY"
  printf '<p>Resolve conflicts before merging.</p>\n' >> "$REPORT_SUMMARY"
else
  printf '<p><strong>Result:</strong> &#9989; No conflicts &mdash; all target branches are clean.</p>\n' >> "$REPORT_SUMMARY"
fi
printf '</body></html>\n' >> "$REPORT_SUMMARY"

echo ""
echo "=========================================="
echo "Pre-merge conflict check completed"
echo "=========================================="

if [ "$HAS_CONFLICTS" = true ]; then
  echo "STATUS: ⚠️  CONFLICTS FOUND"
  echo ""
  echo "The following branches would have merge conflicts:$CONFLICT_BRANCHES"
  echo ""
  echo "See the 'conflict-reports' artifacts for the full HTML report per branch."
  exit 1
else
  echo "STATUS: ✅ NO CONFLICTS FOUND"
  echo ""
  echo "All target branches can be merged without conflicts."
fi
