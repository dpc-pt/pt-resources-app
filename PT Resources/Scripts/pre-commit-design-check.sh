#!/bin/bash

# Pre-commit hook for PT Resources Design System validation
# This script runs before each git commit to ensure design system compliance

echo "🎨 Running PT Resources Design System validation..."

# Get the directory of this script
SCRIPT_DIR="$(dirname "$0")"

# Run the design system validation
if "$SCRIPT_DIR/validate_design_system.sh"; then
    echo "✅ Design system validation passed - commit allowed"
    exit 0
else
    echo ""
    echo "❌ Design system validation failed - commit blocked"
    echo ""
    echo "To fix these issues:"
    echo "1. Review the violations listed above"
    echo "2. Update your code to use PTDesignTokens instead of deprecated patterns"
    echo "3. Refer to DESIGN_SYSTEM_RULES.md for guidance"
    echo "4. Run 'Scripts/validate_design_system.sh' to check your fixes"
    echo ""
    echo "Common fixes:"
    echo "  .ptCoral → PTDesignTokens.Colors.tang"
    echo "  .ptNavy → PTDesignTokens.Colors.ink"  
    echo "  PTSpacing.md → PTDesignTokens.Spacing.md"
    echo "  PTFont.cardTitle → PTFont.ptCardTitle"
    echo ""
    exit 1
fi