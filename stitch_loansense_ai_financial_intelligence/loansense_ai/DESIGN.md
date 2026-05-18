---
name: LoanSense AI
colors:
  surface: '#131314'
  surface-dim: '#131314'
  surface-bright: '#3a393a'
  surface-container-lowest: '#0e0e0f'
  surface-container-low: '#1c1b1c'
  surface-container: '#201f20'
  surface-container-high: '#2a2a2b'
  surface-container-highest: '#353436'
  on-surface: '#e5e2e3'
  on-surface-variant: '#c7c6cc'
  inverse-surface: '#e5e2e3'
  inverse-on-surface: '#313031'
  outline: '#909096'
  outline-variant: '#46464c'
  surface-tint: '#c3c6d7'
  primary: '#c3c6d7'
  on-primary: '#2c303d'
  primary-container: '#0a0e1a'
  on-primary-container: '#777b8a'
  inverse-primary: '#5a5e6d'
  secondary: '#c6c6cd'
  on-secondary: '#2f3036'
  secondary-container: '#45464d'
  on-secondary-container: '#b5b4bc'
  tertiary: '#dbc3a8'
  on-tertiary: '#3c2e1b'
  tertiary-container: '#170c01'
  on-tertiary-container: '#8c7861'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#dfe2f3'
  primary-fixed-dim: '#c3c6d7'
  on-primary-fixed: '#171b28'
  on-primary-fixed-variant: '#434654'
  secondary-fixed: '#e3e2e9'
  secondary-fixed-dim: '#c6c6cd'
  on-secondary-fixed: '#1a1b21'
  on-secondary-fixed-variant: '#45464d'
  tertiary-fixed: '#f8dec3'
  tertiary-fixed-dim: '#dbc3a8'
  on-tertiary-fixed: '#261908'
  on-tertiary-fixed-variant: '#544430'
  background: '#131314'
  on-background: '#e5e2e3'
  surface-variant: '#353436'
typography:
  display-lg:
    fontFamily: Space Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '500'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  data-mono:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.0'
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.0'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 80px
  gutter: 24px
  margin: 40px
---

## Brand & Style

This design system is built upon a high-tech, futuristic aesthetic tailored for the elite financial sector. The visual language conveys intelligence, precision, and forward-looking clarity. By blending **Glassmorphism** with a **High-Tech** digital atmosphere, the interface feels less like a static tool and more like an advanced cockpit for financial navigation.

The system prioritizes depth and luminosity. Surfaces are treated as semi-transparent lenses that sit above a vast, dark digital space. Interaction is defined by "AI glow" responses—subtle light emissions that signify the processing of data and the delivery of insights. The emotional goal is to evoke a sense of absolute security and technical superiority, ensuring users feel they are interacting with the most advanced financial intelligence available.

## Colors

The palette is anchored by a foundational Deep Navy, providing a high-contrast canvas for luminous data points. 

- **Primary Canvas:** A deep, obsidian-like navy (#0A0E1A) that absorbs light and allows accents to pop.
- **AI Accents:** Dual-tone luminosity using Cyan and Violet. Cyan represents active processing and data streams, while Violet signifies premium intelligence and advanced logic.
- **Semantic Risk System:** Critical financial indicators use a glowing semantic scale. "Safe" status emits a soft emerald radiance; "Moderate" uses a concentrated amber; and "Dangerous" utilize a piercing crimson to demand immediate attention.
- **Glassmorphic Surfaces:** Overlays use a desaturated white with ultra-low opacity to maintain the dark-mode aesthetic while creating distinct structural layers.

## Typography

This design system utilizes a dual-font strategy to balance futuristic character with financial readability. 

**Space Grotesk** is used for headlines and data displays to reinforce the technical, "machine-intelligence" vibe. Its geometric construction makes financial figures appear precise and engineered.

**Inter** is utilized for body text and descriptive labels. It provides the necessary clarity for long-form financial insights and ensures that complex data remains accessible and legible under various lighting conditions. High contrast is maintained throughout the system, with AI-driven insights often highlighted through increased weight or the Cyan accent color.

## Layout & Spacing

The layout philosophy emphasizes **Vertical Scanning** and expansive whitespace to prevent information overload.

- **Grid Model:** A 12-column fluid grid system with generous 24px gutters.
- **Visual Rhythm:** An 8px linear scale governs all spacing.
- **Hierarchy of Space:** Large "XL" gaps are used to separate distinct AI modules, ensuring the user's eye can rest between data-heavy sections. 
- **Alignment:** All insights are left-aligned to a strict vertical axis, facilitating quick scanning of financial risk assessments. Floating elements (docks and capsules) exist outside the traditional grid flow to indicate their "live" or "intelligent" nature.

## Elevation & Depth

Depth is achieved through translucency and light rather than traditional shadows.

1.  **Backdrop Layer:** The Deep Navy base.
2.  **Mid-Ground:** Glassmorphic cards with a 20px backdrop blur and a 1px white border (12% opacity). This creates a "frosted" effect that lets background gradients peek through.
3.  **Active Layer:** Elements currently being analyzed by the AI receive a "Cyan glow" (box-shadow with high spread and low opacity).
4.  **Foreground:** Floating docks and Insight Capsules occupy the highest elevation, using higher opacity (10% - 15%) and sharper contrast to sit "above" the data.

## Shapes

The shape language is sophisticated and modern. 

Standard components utilize **Rounded (0.5rem)** corners to maintain a professional yet accessible feel. However, for specialized AI components like **Insight Capsules** and **Floating Docks**, the system employs a pill-shaped (full-round) aesthetic. This distinction helps the user immediately identify "Intelligent" elements versus "Data" elements. Borders are always kept at a consistent 1px thickness to ensure the UI feels sharp and high-definition.

## Components

### Floating Docks
Navigation and primary toolbars are treated as floating glass pods anchored at the bottom of the viewport. They use a high blur-radius and contain icons that glow Cyan upon interaction.

### Glowing Buttons
Primary actions are not solid colors but gradients (Cyan to Violet) with an outer bloom. The hover state increases the intensity of the "AI glow" effect, making the button appear to energize.

### Insight Capsules
Small, pill-shaped tags used for risk categorization. Their borders are color-coded based on the Risk System (Green, Amber, Red). They feature a 2% semi-transparent fill of their respective risk color to create a "contained light" effect.

### Glassmorphic Cards
The primary container for all content. Borders must be subtle (#FFFFFF at 12% opacity). Content inside cards should be grouped with significant internal padding (24px - 32px) to prevent a cluttered "corporate" look.

### Animated Scan-Lines
A decorative but functional element. A horizontal, 1px Cyan line with a soft trailing gradient should periodically move vertically through active data cards to simulate "Real-time AI Scanning."

### Data Inputs
Input fields are minimal, consisting only of a bottom border in the Cyan accent. When focused, the border glows and a very faint violet gradient fills the background of the input.