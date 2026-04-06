```markdown
# Design System Strategy: The Kinetic Vault

## 1. Overview & Creative North Star: "The Digital Obsidian"
This design system moves away from the "banking template" to embrace a philosophy we call **The Digital Obsidian**. It treats the interface not as a flat screen, but as a multi-dimensional space carved from dark, precious materials. 

To break the "standard" UI feel, we prioritize **intentional asymmetry** and **tonal depth**. Rather than placing elements on a grid like a spreadsheet, we use overlapping glass layers and high-contrast typography to guide the eye. The goal is an experience that feels as much like a high-end editorial magazine as it does a secure financial tool—secure yet breathable, professional yet avant-garde.

---

## 2. Colors & Surface Philosophy
The palette is rooted in a deep charcoal base, punctuated by a hyper-vibrant teal that represents liquid capital and movement.

### The "No-Line" Rule
**Prohibit 1px solid borders for sectioning.** Boundaries must never be structural "boxes." Instead, define space through:
*   **Background Shifts:** Transitioning from `surface` (#131317) to `surface-container-low` (#1B1B1F).
*   **Tonal Gradients:** Using a subtle linear gradient from `surface-container` to `surface-container-lowest` to imply a physical edge.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack. The closer an item is to the user, the lighter its surface becomes:
1.  **Base Layer:** `surface` (#131317) - The foundation.
2.  **Sectional Layer:** `surface-container-low` (#1B1B1F) - Large grouping areas.
3.  **Interactive Layer:** `surface-container-high` (#2A292E) - Cards and actionable modules.
4.  **Floating Layer:** `surface-bright` (#39393D) - Tooltips and active modals.

### The "Glass & Gradient" Rule
Standard flat colors are forbidden for primary CTAs. Use a **Signature Texture**: A diagonal gradient from `primary` (#6BD8CB) to `primary-container` (#29A195). For "floating" elements, utilize Glassmorphism: `surface-variant` at 60% opacity with a `20px` backdrop blur to allow the deep charcoal base to bleed through.

---

## 3. Typography: Editorial Authority
We utilize two distinct typefaces to create a "Signature Hierarchy."

*   **Display & Headlines (Manrope):** Chosen for its geometric precision and modern "tech-wealth" aesthetic. 
    *   *Usage:* Use `display-lg` for account balances and `headline-md` for section titles. These should feel heavy and authoritative.
*   **Body & Labels (Inter):** Chosen for maximum legibility in dense financial data.
    *   *Usage:* `body-md` for transaction descriptions; `label-sm` for metadata.

**The Editorial Rule:** Never center-align long-form data. Use aggressive left-alignment and generous leading (line height) to create a "columnar" look reminiscent of a financial broadsheet.

---

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are too "dirty" for this aesthetic. We achieve depth through light, not shadow.

*   **The Layering Principle:** Place a `surface-container-lowest` card inside a `surface-container-high` container to create an "inset" look, simulating a carved-out space for data.
*   **Ambient Glows:** For primary cards, replace shadows with a 4% opacity glow using the `primary` token (#6BD8CB). The blur should be large (32px+) to mimic a soft light source behind the card.
*   **The "Ghost Border" Fallback:** If accessibility requires a stroke, use the `outline-variant` (#3D4947) at **15% opacity**. It should be felt, not seen.
*   **Kinetic Glass:** Floating headers must use 40% `surface-container` with a heavy `backdrop-blur`. This ensures the user feels the "speed" of the app as content scrolls beneath the frosted glass.

---

## 5. Components

### Cards & Lists
*   **The Rule:** Forbid divider lines. 
*   **Execution:** Separate transactions using vertical whitespace (16px) or by alternating the background between `surface-container-low` and `surface-container-lowest`. 
*   **High-Fidelity Cards:** Use a `xl` (0.75rem) corner radius. Apply a subtle top-down gradient and a 1px "Ghost Border" only on the top edge to simulate a light catch.

### Buttons
*   **Primary:** Gradient of `primary` to `primary-container`. No border. High-contrast `on-primary` text.
*   **Secondary:** Ghost style. No background, 1px `outline-variant` at 30%, text in `primary`.
*   **Tertiary:** Text-only using `primary-fixed-dim`. 

### Input Fields
*   **State:** Default state should be `surface-container-highest`. On focus, the background remains, but a 1px glow of `primary` is applied to the bottom edge only.
*   **Typography:** Labels use `label-md` in `on-surface-variant`.

### Financial-Specific Components
*   **Trend Sparklines:** Use `primary` for growth and `tertiary` (#FFB2B9) for decline. Lines should be 2px thick with a soft glow.
*   **Insight Chips:** Use the sophisticated secondary palette. A "Savings" chip uses `secondary-container` (#4F319C) with `on-secondary-container` (#BEA8FF) text.

---

## 6. Do's and Don'ts

### Do
*   **DO** use whitespace as a functional tool to separate "Spending" from "Savings" rather than lines.
*   **DO** overlap elements (e.g., a card slightly overhanging a section header) to create a bespoke, custom-coded feel.
*   **DO** use "Manrope" for all numerical data to emphasize the premium financial aspect.

### Don't
*   **DON'T** use pure black (#000000). Use the `surface` token to maintain depth and prevent "smearing" on OLED screens.
*   **DON'T** use 100% opacity borders. It breaks the "Digital Obsidian" illusion of carved material.
*   **DON'T** use standard "Material Blue" for links. Always stay within the Teal/Cyan/Mint spectrum to maintain the signature brand voice.

### Accessibility Note
While we prioritize "Ghost Borders" and tonal shifts, always ensure that text-to-background contrast meets WCAG AA standards using the `on-surface` and `on-primary` tokens. Low-contrast elements should be purely decorative.```