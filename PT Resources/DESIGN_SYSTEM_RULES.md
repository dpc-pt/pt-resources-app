# PT Resources Design System Rules

This document establishes the design system rules that MUST be followed when developing the PT Resources iOS app to ensure consistency with the Proclamation Trust website.

## 🎨 Core Design Principles

### Brand Colors (MANDATORY)
**Always use `PTDesignTokens.Colors` - NEVER hardcode colors**

```swift
// ✅ CORRECT - Using design tokens
.foregroundColor(PTDesignTokens.Colors.ink)
.background(PTDesignTokens.Colors.surface)

// ❌ WRONG - Hardcoded colors
.foregroundColor(.blue)
.background(Color(hex: "#ff4c23"))
```

**Primary Brand Colors:**
- **Ink** (`PTDesignTokens.Colors.ink`): `#07324c` - Primary text, headings
- **Tang** (`PTDesignTokens.Colors.tang`): `#ff4c23` - Primary actions, highlights
- **Klein Blue** (`PTDesignTokens.Colors.kleinBlue`): `#4060ab` - Secondary actions
- **Lawn** (`PTDesignTokens.Colors.lawn`): `#0f9679` - Success states
- **Turmeric** (`PTDesignTokens.Colors.turmeric`): `#ff921c` - Warning states

**Semantic Colors:**
- **Background**: `PTDesignTokens.Colors.background` - Main backgrounds
- **Surface**: `PTDesignTokens.Colors.surface` - Card/container backgrounds
- **Light**: `PTDesignTokens.Colors.light` - Borders, dividers
- **Medium**: `PTDesignTokens.Colors.medium` - Secondary text
- **Success**: `PTDesignTokens.Colors.success` - Success states
- **Error**: `PTDesignTokens.Colors.error` - Error states

### Typography (MANDATORY)
**Always use `PTFont` - NEVER use system fonts directly**

```swift
// ✅ CORRECT - Using PT typography
Text("Section Title").font(PTFont.ptSectionTitle)
Text("Body text").font(PTFont.ptBodyText)

// ❌ WRONG - Direct system fonts
Text("Section Title").font(.title)
Text("Body text").font(.body)
```

**Typography Scale:**
- `PTFont.ptDisplayLarge` - Large display text
- `PTFont.ptDisplayMedium` - Medium display text
- `PTFont.ptSectionTitle` - Section headings
- `PTFont.ptCardTitle` - Card titles
- `PTFont.ptCardSubtitle` - Card subtitles
- `PTFont.ptBodyText` - Regular body text
- `PTFont.ptCaptionText` - Small text, captions
- `PTFont.ptLogoText` - Logo text

### Spacing (MANDATORY)
**Always use `PTDesignTokens.Spacing` - NEVER hardcode spacing**

```swift
// ✅ CORRECT - Using design tokens
VStack(spacing: PTDesignTokens.Spacing.md)
.padding(PTDesignTokens.Spacing.lg)

// ❌ WRONG - Hardcoded spacing
VStack(spacing: 16)
.padding(24)
```

**Spacing Scale:**
- `PTDesignTokens.Spacing.xs` - 4pt
- `PTDesignTokens.Spacing.sm` - 8pt  
- `PTDesignTokens.Spacing.md` - 16pt
- `PTDesignTokens.Spacing.lg` - 24pt
- `PTDesignTokens.Spacing.xl` - 32pt
- `PTDesignTokens.Spacing.xxl` - 48pt
- `PTDesignTokens.Spacing.screenEdges` - 20pt (screen padding)

### Border Radius (MANDATORY)
**Always use `PTDesignTokens.BorderRadius` - NEVER hardcode corner radius**

```swift
// ✅ CORRECT - Using design tokens
.cornerRadius(PTDesignTokens.BorderRadius.card)
RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)

// ❌ WRONG - Hardcoded radius
.cornerRadius(8)
RoundedRectangle(cornerRadius: 12)
```

**Border Radius Scale:**
- `PTDesignTokens.BorderRadius.sm` - 4pt
- `PTDesignTokens.BorderRadius.md` - 6pt (default)
- `PTDesignTokens.BorderRadius.lg` - 8pt
- `PTDesignTokens.BorderRadius.xl` - 12pt
- `PTDesignTokens.BorderRadius.card` - 12pt
- `PTDesignTokens.BorderRadius.button` - 6pt

## 🚫 FORBIDDEN PRACTICES

### Never Use These (WILL BREAK DESIGN CONSISTENCY):

```swift
// ❌ OLD COLOR SYSTEM - FORBIDDEN
.ptCoral, .ptNavy, .ptRoyalBlue, .ptTurquoise
.ptPrimary, .ptSecondary, .ptBackground, .ptSurface
.ptMediumGray, .ptDarkGray, .ptLightGray

// ❌ OLD SPACING SYSTEM - FORBIDDEN  
PTSpacing.md, PTSpacing.lg, PTSpacing.screenPadding
PTCornerRadius.small, PTCornerRadius.medium

// ❌ OLD TYPOGRAPHY - FORBIDDEN
PTFont.cardTitle, PTFont.bodyText (without 'pt' prefix)
PTFont.captionText, PTFont.sectionTitle

// ❌ HARDCODED VALUES - FORBIDDEN
.foregroundColor(.blue)
.padding(16)
.cornerRadius(8)
Color(hex: "#ff4c23")

// ❌ DEPRECATED METHODS - FORBIDDEN
.ptCardStyle(), .ptIconStyle(), .ptPrimaryButton()
.registerPTFonts()
```

## ✅ COMPONENT PATTERNS

### Card Components
```swift
// ✅ CORRECT Card Pattern
VStack(spacing: PTDesignTokens.Spacing.sm) {
    // Content
}
.padding(PTDesignTokens.Spacing.md)
.background(
    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
        .fill(PTDesignTokens.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
        )
)
.scaleEffect(isPressed ? 0.98 : 1.0)
```

### Button Components
```swift
// ✅ CORRECT Primary Button Pattern
Button(action: action) {
    Text("Action")
        .font(PTFont.ptCardTitle)
        .foregroundColor(.white)
}
.padding(.horizontal, PTDesignTokens.Spacing.lg)
.padding(.vertical, PTDesignTokens.Spacing.md)
.background(
    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
        .fill(PTDesignTokens.Colors.tang)
)
```

### Logo Usage
```swift
// ✅ CORRECT Logo Usage
PTLogo(size: 64, showText: true)
// Available sizes: 16, 24, 32, 40, 48, 64, 80, 120
```

## 🔍 VALIDATION RULES

### Before Every Commit:
1. **No hardcoded colors** - Search for `Color(`, `.blue`, `.red`, etc.
2. **No hardcoded spacing** - Search for `.padding(16)`, `spacing: 24`, etc.
3. **No old system references** - Search for `PTSpacing.`, `.ptCoral`, etc.
4. **Typography consistency** - All text uses `PTFont.pt*` variants
5. **Proper component structure** - Cards, buttons follow established patterns

### Code Review Checklist:
- [ ] All colors use `PTDesignTokens.Colors.*`
- [ ] All spacing uses `PTDesignTokens.Spacing.*` 
- [ ] All corner radius uses `PTDesignTokens.BorderRadius.*`
- [ ] All typography uses `PTFont.pt*` variants
- [ ] No deprecated methods (`.ptCardStyle()`, etc.)
- [ ] Components follow established patterns
- [ ] Accessibility labels present where needed

## 🎯 DESIGN GOALS ACHIEVED

This design system ensures:
- **Brand Consistency**: Matches Proclamation Trust website exactly
- **Maintainability**: Centralized design tokens allow global updates
- **Developer Experience**: Clear, predictable naming conventions
- **Scalability**: Easy to add new components following established patterns
- **Quality**: Prevents design inconsistencies through systematic approach

---

## 📋 QUICK REFERENCE

**Need a color?** → `PTDesignTokens.Colors.*`
**Need spacing?** → `PTDesignTokens.Spacing.*`
**Need typography?** → `PTFont.pt*`
**Need border radius?** → `PTDesignTokens.BorderRadius.*`
**Need a logo?** → `PTLogo(size:, showText:)`

**Remember**: When in doubt, follow existing patterns in updated files like `HomeView.swift`, `TalkRowView.swift`, and `MainTabView.swift`.