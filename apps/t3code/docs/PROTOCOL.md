# Protocol and design evidence — 0.2.1

Research/validation: 2026-10-26. Running host: **0.1.3-nightly.20261026.3726**, orchestration protocol **2**. Keep the desktop session running; the LAN adapter is a separate process.

## Sources

Official current mobile design was inspected at [`9bc0c334383a43af5390283e9b10f999acc021b8`](https://github.com/pingdotgg/t3code/tree/9bc0c334383a43af5390283e9b10f999acc021b8). Host-era command/schema research was cross-checked at [`0b0417a56b2091c87760470833b337eaa0b9a304`](https://github.com/pingdotgg/t3code/tree/0b0417a56b2091c87760470833b337eaa0b9a304), then exercised on the running host. A protocol number alone does not guarantee future schema compatibility.

- `packages/contracts/src/environmentHttp.ts`: discovery, OAuth, shell, bounded thread/project reads.
- `packages/contracts/src/orchestrationV2.ts`: commands, receipts, projections, runtime requests/questions.
- `packages/contracts/src/modelSelection.ts`, `providerPolicy.ts`: model routing/options and decisions.
- `apps/server/src/ws.ts`, `OrchestrationProtocol.ts`: `/ws?orchestrationProtocol=2`, Effect JSON RPC transport.
- `packages/contracts/src/rpc.ts`, `server.ts`: `server.getConfig`, model catalog, RPC authorization.

## Implemented wire behavior

Discovery must identify the same environment as the saved credential and advertise protocol 2. Authenticated HTTP reads carry `Authorization: Bearer …` and `x-t3-orchestration-protocol: 2`. New app OAuth bootstrap exchange requests exactly `orchestration:read orchestration:operate`; no filesystem, terminal, settings, provider-management, or access-administration scopes are requested.

The gateway uses a masked RFC6455 WebSocket upgrade to loopback. Its Effect JSON frame is `{_tag:"Request",id:"1",tag:"orchestration.dispatchCommand",payload:<command>,headers:[]}`. Success is the matching `Exit` with a `Success` value. Frames/messages, fragmented data, control pings, elapsed time, and total bytes are bounded. RPC authorization failures are rejected; uncertain delivery returns 409. No command is automatically replayed. A receipt's sequence is returned to the app.

`thread.create` specifies a client-generated thread/command ID, project, model selection, `createdBy:"user"`, `creationSource:"mobile"`, `runtimeMode:"approval-required"`, `interactionMode:"default"`, and null branch/worktree. `message.dispatch` adds an independent message ID, text, empty attachments, and `start_immediately` or `queue_after_active`. Model selection is `{instanceId,model,options?}`. Existing model options are retained when that selection is unchanged.

`runtime-request.respond` joins a pending runtime request ID to its turn item. Approval responses require `responseCapability.type="live"`; user input accepts `live` or `message`. `not_resumable` requests have no response action. Decisions come from the host's choices, with Allow once/Decline fallback. Answers map question IDs to strings or arrays for multiple selection. No guessed generic REST send/approval endpoints are used.

Thread reads replace bounded snapshots, so reconnect does not depend on replay cursors or retaining an unbounded event log. Polling is intentionally used instead of a persistent socket on the iPad: iOS 10 has no NSURLSessionWebSocketTask, and one small foreground polling lifecycle is easier to recover after suspension. This is live updating with bounded latency, not token-by-token push streaming.

## Official mobile appearance

This is the official **T3 Code** dark palette, despite the companion's display name “T3 Code.” Upstream has a separate purple T3 Code palette; that was not selected.

| Element | Adaptation from official mobile source |
|---|---|
| Canvas/chrome, sidebar, surface | `#0a0a0a`, `#000000`, `#111111` |
| Foreground, muted, border | `#f5f5f5`, `#818181`, `#191919` |
| Action blue, selected row | `#346bf1`, `#1a1b1b` |
| Type | Bundled DM Sans regular/medium/bold; body 16/23, tool text 14/19, labels 13/17, code 13/19 |
| Sidebar | 32% width clamped 280–380; about 328 points on 1024×768 |
| Messages | Right-aligned 20-point user bubbles, assistant text directly on the canvas |
| Composer | Dark rounded 27-point container; provider/model toolbar and 44-point actions |

Evidence: `packages/shared/src/themePalettes.ts`; mobile `src/lib/{mobileTheme,typography,fontFamilies,layout}.ts`; `app.config.ts`; `features/threads/{ThreadFeed,ThreadComposer,ThreadNavigationSidebar}.tsx`; `components/ComposerToolbar.tsx`; `thread-list-v2-row-appearance.ts`. The app adapts these tokens/layouts to legacy CSS; it does not ship React Native or the official app's implementation. Blur and animation are omitted for the A7. Font licensing/source is bundled beside the fonts.
