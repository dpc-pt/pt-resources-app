#!/bin/bash

# PT Resources Design System Validation Script
# This script checks for design system rule violations

set -e

echo "🎨 PT Resources Design System Validation"
echo "========================================"

VIOLATIONS=0
PROJECT_ROOT="$(dirname "$0")/.."
SWIFT_FILES="$PROJECT_ROOT/PT Resources"

# Function to report violations
report_violation() {
    echo "❌ VIOLATION: $1"
    echo "   File: $2"
    echo "   Line: $3"
    echo ""
    ((VIOLATIONS++))
}

# Function to check for deprecated color usage
check_deprecated_colors() {
    echo "🔍 Checking for deprecated color usage..."
    
    # Check for old color system
    grep -rn --include="*.swift" \
        -e "\.ptCoral" -e "\.ptNavy" -e "\.ptRoyalBlue" -e "\.ptTurquoise" \
        -e "\.ptPrimary" -e "\.ptSecondary" -e "\.ptMediumGray" -e "\.ptDarkGray" \
        -e "\.ptLightGray" -e "\.ptGreen" -e "\.ptSuccess" \
        "$SWIFT_FILES" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        report_violation "Deprecated color usage: $content" "$file" "$line_num"
    done
    
    # Check for hardcoded Color() usage (exclude PTDesignTokens.swift where colors are defined)
    grep -rn --include="*.swift" \
        -e "Color(" -e "\.foregroundColor(\.blue" -e "\.foregroundColor(\.red" -e "\.foregroundColor(\.green" \
        -e "\.foregroundColor(\.yellow" -e "\.foregroundColor(\.orange" -e "\.foregroundColor(\.purple" \
        -e "\.foregroundColor(\.pink" -e "\.foregroundColor(\.gray" -e "Color\.blue" -e "Color\.red" \
        -e "Color\.green" -e "Color\.yellow" -e "Color\.orange" -e "Color\.purple" -e "Color\.pink" -e "Color\.gray" \
        "$SWIFT_FILES" | grep -v "PTDesignTokens.Colors" | grep -v "PTDesignTokens.swift" | grep -v "PTTheme.swift" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        # Skip legitimate uses like Color.clear, Color.white, system colors, etc.
        if [[ ! "$content" =~ (Color\.clear|\.white|\.black|\.accentColor|\.primary|\.secondary|Color\(\.system|Color\(UIColor) ]]; then
            report_violation "Hardcoded color usage: $content" "$file" "$line_num"
        fi
    done
}

# Function to check for deprecated spacing usage
check_deprecated_spacing() {
    echo "🔍 Checking for deprecated spacing usage..."
    
    # Check for old spacing system (exclude PTTheme.swift which may have legacy references)
    grep -rn --include="*.swift" \
        -e "PTSpacing\." -e "PTCornerRadius\." \
        "$SWIFT_FILES" | grep -v "PTTheme.swift" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        report_violation "Deprecated spacing/radius usage: $content" "$file" "$line_num"
    done
    
    # Check for hardcoded spacing values
    grep -rn --include="*.swift" \
        -e "\.padding([0-9]" -e "spacing: [0-9]" -e "\.cornerRadius([0-9]" \
        "$SWIFT_FILES" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        report_violation "Hardcoded spacing/radius: $content" "$file" "$line_num"
    done
}

# Function to check for deprecated typography usage
check_deprecated_typography() {
    echo "🔍 Checking for deprecated typography usage..."
    
    # Check for old font system (PTFont without 'pt' prefix)
    grep -rn --include="*.swift" \
        -e "PTFont\.cardTitle" -e "PTFont\.bodyText" -e "PTFont\.captionText" \
        -e "PTFont\.sectionTitle" -e "PTFont\.cardSubtitle" \
        "$SWIFT_FILES" | grep -v "PTFont\.pt" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        report_violation "Deprecated font usage: $content" "$file" "$line_num"
    done
    
    # Check for direct system font usage
    grep -rn --include="*.swift" \
        -e "\.font(\.title" -e "\.font(\.body" -e "\.font(\.caption" \
        -e "\.font(\.headline" -e "\.font(\.subheadline" \
        "$SWIFT_FILES" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        report_violation "Direct system font usage: $content" "$file" "$line_num"
    done
}

# Function to check for deprecated methods
check_deprecated_methods() {
    echo "🔍 Checking for deprecated methods..."
    
    # Check for old component methods
    grep -rn --include="*.swift" \
        -e "\.ptCardStyle(" -e "\.ptIconStyle(" -e "\.ptPrimaryButton(" \
        -e "\.registerPTFonts(" -e "\.ptPrimaryStyle(" \
        "$SWIFT_FILES" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        report_violation "Deprecated method usage: $content" "$file" "$line_num"
    done
}

# Function to check for proper PTDesignTokens usage
check_design_token_usage() {
    echo "🔍 Checking for proper PTDesignTokens usage..."
    
    # Check that PTDesignTokens.Colors is being used
    if ! grep -rq --include="*.swift" "PTDesignTokens\.Colors\." "$SWIFT_FILES"; then
        echo "⚠️  WARNING: No PTDesignTokens.Colors usage found - this might indicate a problem"
    fi
    
    # Check that PTDesignTokens.Spacing is being used
    if ! grep -rq --include="*.swift" "PTDesignTokens\.Spacing\." "$SWIFT_FILES"; then
        echo "⚠️  WARNING: No PTDesignTokens.Spacing usage found - this might indicate a problem"
    fi
    
    # Check that PTFont.pt* variants are being used
    if ! grep -rq --include="*.swift" "PTFont\.pt" "$SWIFT_FILES"; then
        echo "⚠️  WARNING: No PTFont.pt* usage found - this might indicate a problem"
    fi
}

# Function to check component patterns
check_component_patterns() {
    echo "🔍 Checking component patterns..."
    
    # Look for potential card components that should use the standard pattern
    grep -rn --include="*.swift" \
        -e "RoundedRectangle.*fill.*Color\." \
        "$SWIFT_FILES" | grep -v "PTDesignTokens.Colors" | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        content=$(echo "$line" | cut -d: -f3-)
        report_violation "Card component not using design tokens: $content" "$file" "$line_num"
    done
}

# Run all checks
echo "Starting validation..."
echo ""

check_deprecated_colors
check_deprecated_spacing  
check_deprecated_typography
check_deprecated_methods
check_design_token_usage
check_component_patterns

echo "========================================"
if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ VALIDATION PASSED: No design system violations found!"
    echo "🎉 Your code follows PT Resources design system rules."
else
    echo "❌ VALIDATION FAILED: Found $VIOLATIONS design system violations"
    echo "📖 Please review DESIGN_SYSTEM_RULES.md for guidance"
    exit 1
fi