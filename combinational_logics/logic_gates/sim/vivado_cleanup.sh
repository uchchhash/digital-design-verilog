#!/bin/bash
set -e

echo "🧹 Vivado cleanup …"

# Detect .xpr in current folder or one level below
proj_xpr=$(find . -maxdepth 2 -name "*.xpr" | head -n1)

if [ -z "$proj_xpr" ]; then
    echo "❌ No Vivado project (.xpr) found here or one level down!"
    exit 1
fi

proj_dir=$(dirname "$proj_xpr")
proj_name="${proj_xpr%.xpr}"

echo "📂 Found Vivado project: $proj_xpr"
cd "$proj_dir"

# Find all files to KEEP
keep_files=(
    "$(basename "$proj_xpr")"
)

# Add .log, .rpt, .wdb
while IFS= read -r file; do
    keep_files+=("$file")
done < <(find . -type f \( -name "*.log" -o -name "*.rpt" -o -name "*.wdb" \))

echo "✅ Keeping the following files:"
for f in "${keep_files[@]}"; do
    echo "    $f"
done

# Find all files in project dir
all_files=$(find . -type f)

# Delete files not in keep list
for f in $all_files; do
    skip=false
    for keep in "${keep_files[@]}"; do
        if [[ "$f" == "$keep" ]]; then
            skip=true
            break
        fi
    done
    if [ "$skip" = false ]; then
        echo "🗑️  Deleting: $f"
        rm -f "$f"
    fi
done

# Remove empty dirs
find . -type d -empty -delete

echo "🎯 Cleanup complete for: $proj_dir"
