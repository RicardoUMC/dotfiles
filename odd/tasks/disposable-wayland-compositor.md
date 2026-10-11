# Disposable Wayland compositor

## Goal
Provide a CPU-only, no-device Wayland compositor for validating `Tokyo.Diagnostics` subsurface ordering without touching the active Hyprland session.

## Constraints
- Never inherit or connect to the active `WAYLAND_DISPLAY`.
- Never expose `/dev/dri` or `/dev/udmabuf`.
- No package installation and no push.
- Run through the existing fail-closed `bwrap`/`systemd-run` boundary with a private runtime directory, bounded deadline, and identity-based cleanup.
- Keep blur and `BackgroundEffect` out of scope.
- Do not claim visual ordering from protocol success or clean process exit alone.

## Tasks
1. Define the minimal server contract and evidence format. **Done** — the no-device boundary, required protocol surface, paired ordering evidence, and fail-closed criteria are recorded below.
2. Implement a standalone CPU-only compositor using installed libwayland-server and generated xdg-shell server bindings. **Done** — `tokyo-wayland-compositor` builds cleanly with generated xdg-shell bindings and emits bounded CPU frame/state evidence.
3. Add a bounded paired client exercise for below-parent and above-parent subsurface ordering. **Done** — the QtWayland adapter now creates two contrasting sibling subsurfaces and the order selector controls their relative stacking; build verification passed.
4. Integrate the paired compositor/client exercise into the isolated launcher, then verify containment, protocol behavior, framebuffer ordering, teardown, and post-client liveness. **Done** — the contained below/above runs exited cleanly with private sockets, no device exposure, reversed stable child stacks (`4,3` vs `3,4`), and different CPU framebuffer digests.
5. Review and document limitations; keep blur validation blocked. **Done** — self-parent and ancestor-cycle guards are implemented, the installed-API negative probe is integrated into the contained launcher, and the bounded run verifies nonzero client/compositor rejection exits alongside the unchanged positive ordering checks.

## Acceptance evidence
- Private socket created and owned only by the disposable unit.
- No inherited desktop socket or device node visible inside the sandbox.
- Qt client connects, receives configure, commits parent and child surfaces, and exits through the bounded lifecycle.
- Below/above runs produce distinguishable CPU framebuffer results with matching protocol traces.
- Compositor and client terminate; socket and runtime directory are removed by identity.
- Any unavailable dependency or ambiguous evidence fails closed and remains documented as pending.
- Reliability hardening: reject self-parenting and ancestor subsurface cycles before assigning the role; the positive ordering cases require both child exit statuses to be zero, while negative regression cases require both exits to be nonzero.
- Limitations: this proves contained Wayland protocol behavior and CPU framebuffer ordering only; it does not validate live Hyprland rendering, blur, `BackgroundEffect`, GPU behavior, or visual compositor output.

## Delivery
Implementation is authorized. Work-unit commit: `c8407d7` (`feat(diagnostics): add contained compositor ordering probe`). Documentation and task evidence are recorded in the follow-up commit. Push is explicitly authorized by the user.
