# Design Tokens — iOS

Source: `TheRecruitingCompass/Core/Theme/AppColors.swift`

## Brand Palette

Raw color values. Access via `Color.Brand.*`. Use `BadgeColor` for semantic badge contexts.

| Token | Hex | Role |
|-------|-----|------|
| `Color.Brand.blue100` | #dbeafe | Blue light background |
| `Color.Brand.blue500` | #3b82f6 | Blue mid (charts, indicators) |
| `Color.Brand.blue600` | #2563eb | Blue primary (actions) |
| `Color.Brand.blue700` | #1d4ed8 | Blue dark (foreground) |
| `Color.Brand.emerald100` | #d1fae5 | Emerald light |
| `Color.Brand.emerald500` | #10b981 | Emerald mid |
| `Color.Brand.emerald600` | #059669 | Emerald primary |
| `Color.Brand.emerald700` | #047857 | Emerald dark |
| `Color.Brand.orange100` | #ffedd5 | Orange light |
| `Color.Brand.orange500` | #f97316 | Orange mid |
| `Color.Brand.orange600` | #ea580c | Orange primary |
| `Color.Brand.orange700` | #c2410c | Orange dark |
| `Color.Brand.purple100` | #ede9fe | Purple light |
| `Color.Brand.purple500` | #8b5cf6 | Purple mid |
| `Color.Brand.purple600` | #7c3aed | Purple primary |
| `Color.Brand.purple700` | #6d28d9 | Purple dark |
| `Color.Brand.red100` | #fee2e2 | Red light |
| `Color.Brand.red500` | #ef4444 | Red mid |
| `Color.Brand.red600` | #dc2626 | Red primary |
| `Color.Brand.red700` | #b91c1c | Red dark |
| `Color.Brand.slate100` | #f1f5f9 | Slate light |
| `Color.Brand.slate500` | #64748b | Slate mid |
| `Color.Brand.slate600` | #475569 | Slate primary |
| `Color.Brand.slate700` | #334155 | Slate dark |
| `Color.Brand.indigo100` | #e0e7ff | Indigo light (accent) |
| `Color.Brand.indigo500` | #6366f1 | Indigo mid |
| `Color.Brand.indigo600` | #4f46e5 | Indigo primary |
| `Color.Brand.indigo700` | #4338ca | Indigo dark |

## Semantic Aliases

| Token | Maps to | Use for |
|-------|---------|---------|
| `Color.Semantic.actionPrimary` | `Brand.blue600` | Primary interactive elements |
| `Color.Semantic.success` | `Brand.emerald600` | Success states |
| `Color.Semantic.warning` | `Brand.orange600` | Warning states |
| `Color.Semantic.danger` | `Brand.red600` | Destructive/error states |
| `Color.Semantic.muted` | `Brand.slate500` | Secondary text, disabled |

## Rules

- Never write raw hex (`Color(hex: "3b82f6")`) in views — use `Color.Brand.*`
- Never write system colors (`.green`, `.blue`, `.red`) for semantic status — use `BadgeColor` or `Color.Brand.*`
- System colors (`.primary`, `.secondary`, `.tertiarySystemBackground`) are fine for structural/layout use
