# Copilot Instructions: Idle Steam (Godot)

## Project Overview

This is a **Godot 4.6 desktop widget** - a borderless, transparent, always-on-top application featuring a draggable pet sprite. The app runs as a persistent overlay and responds to both mouse interactions and global keyboard hooks.

**Key characteristics:**
- Single scene (`Main.tscn`) with modular input/animation controllers
- Windows-only C++ GDExtension for background keyboard input capture
- Transparent background with mouse passthrough outside pet sprite boundaries
- Designed for idle/clicker game mechanics

## Architecture

### Component Hierarchy (from [Main.gd](scripts/main/Main.gd))

The application uses a **signal-driven event bus** pattern where `Main` orchestrates:

1. **GlobalKeyHook** - C++ extension detecting background keyboard input (even when unfocused)
2. **DragController** - Handles mouse drag detection with threshold + click distinction
3. **MousePassThroughPolygon** - Manages OS-level mouse passthrough (only blocks input on sprite pixels)
4. **ClickScaleAnimator** - Plays squash-and-stretch animations triggered by clicks or key presses
5. **Pet** - Simple `Sprite2D` node moved by DragController, scaled by ClickScaleAnimator

### Critical Data Flows

**Drag Input Path:**
- `DragController._unhandled_input()` → emits `drag_started` → `Main` moves Pet sprite → `MousePassThroughPolygon._update_passthrough()` recalculates hitbox polygon

**Click Path:**
- Either `DragController.clicked` signal OR `GlobalKeyHook.any_key_pressed` signal → `ClickScaleAnimator._play_click_scale_anim()` tweens scale

## Key Patterns & Conventions

### Signal-Driven Architecture
- **All controllers emit signals, never directly modify targets.** See [Main.gd](scripts/main/Main.gd#L13-L25) for connection pattern
- Signals are the contract; implementations are decoupled

### Hit Detection Pattern
[DragController._hit_target()](scripts/main/DragController.gd#L47-L56) uses **sprite-relative rect collision** (not collision shapes):
```gdscript
# Centers on sprite origin, scales with sprite.scale
var size: Vector2 = target.texture.get_size() * target.scale
var rect := Rect2(-size * 0.5, size)
return rect.has_point(local)
```
Use this pattern if adding new sprite-based targets; don't add CollisionShape2D nodes.

### Drag vs Click Disambiguation
[DragController](scripts/main/DragController.gd#L34-L46) uses **threshold-based state machine**:
- Press on target → `_pending_click = true`
- If motion > `DRAG_THRESHOLD` (6px) → `_dragging = true`
- Release while `_pending_click` → emit `clicked`; while `_dragging` → emit `drag_ended`
This prevents unintended clicks when dragging. Don't lower threshold below 6px without playtesting.

### Mouse Passthrough for Transparent UI
[MousePassThroughPolygon](scripts/main/MousePassThroughPolygon.gd) converts sprite texture bounds to a **screen-space polygon** and passes to OS:
- Must be called after Pet position/scale changes (done in [Main](scripts/main/Main.gd#L33))
- Only works with `Sprite2D` (checked explicitly)
- If sprite becomes null, passthrough resets to empty (no input blocking)

### Tweening for Animations
[ClickScaleAnimator](scripts/main/ClickScaleAnimator.gd) uses **Godot tweens**:
- Kills running tween before creating new one (prevents stacking)
- TRANS_BACK + EASE_OUT for snappy squash-stretch feel
- Timeline: 0.06s shrink → 0.1s expand
Preserve timing for game feel; adjust only if playtesting indicates sluggishness.

## Building & Dependencies

### GDExtension (Windows-only)
The C++ extension at [addons/global_key_hook/](addons/global_key_hook/) requires:
- **Windows SDK** (for `windows.h`, `SetWindowsHookExW`)
- **SCons** build system (via `SConstruct`)
- Pre-built binary: `bin/global_key_hook.windows.debug.x86_64.dll`

**No manual build needed for scripting**—binary is committed. Only rebuild if modifying [src/global_key_hook.cpp](addons/global_key_hook/src/global_key_hook.cpp).

### Project Settings
Window configuration in [project.godot](project.godot#L16-L26):
- `window/size/mode=3` (fullscreen, no decoration)
- `borderless=true`, `always_on_top=true`, `transparent=true`
- `per_pixel_transparency/allowed=true` (required for passthrough)
- Renderer: GL Compatibility (not Forward+)

Changing these affects OS integration; test on actual desktop if modified.

## Development Workflows

### Adding a New Interactive Element
1. Create `Sprite2D` node in scene
2. In [Main.gd](scripts/main/Main.gd), assign to controller via `controller.target = new_sprite`
3. If it needs drag/click: wire to `DragController`
4. If it needs animation: assign to `ClickScaleAnimator` or create new animator
5. Update `MousePassThroughPolygon.target` if multi-target passthrough is needed (currently single-target)

### Debugging Background Input
[GlobalKeyHook.gd](scripts/main/GlobalKeyHook.gd) prints focus events:
```
[FOCUS] OUT (game window inactive)
[FOCUS] IN (game window active)
```
If global keys aren't firing, check console. The C++ hook persists across window focus.

### Modifying Animation Feel
Tweak [ClickScaleAnimator](scripts/main/ClickScaleAnimator.gd):
- `TRANS_BACK` → transition curve (try `TRANS_ELASTIC`, `TRANS_BOUNCE`)
- Durations (0.06s, 0.1s) → speed
- Final scale (0.75) → squeeze intensity

Test with both keyboard and mouse clicks to ensure consistency.

## File Locations Summary
- **Main scene & orchestration**: [scenes/Main.tscn](scenes/Main.tscn), [scripts/main/Main.gd](scripts/main/Main.gd)
- **Input controllers**: [scripts/main/DragController.gd](scripts/main/DragController.gd), [scripts/main/GlobalKeyHook.gd](scripts/main/GlobalKeyHook.gd)
- **Visual feedback**: [scripts/main/ClickScaleAnimator.gd](scripts/main/ClickScaleAnimator.gd), [scripts/main/MousePassThroughPolygon.gd](scripts/main/MousePassThroughPolygon.gd)
- **Windows integration**: [addons/global_key_hook/src/](addons/global_key_hook/src/)
