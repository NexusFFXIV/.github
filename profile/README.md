# NexusFFXIV

**Plugin framework and reusable modules for FINAL FANTASY XIV Dalamud plugins.**

NexusFFXIV is home to three related projects: a plugin-agnostic framework (NexusKit), a set of opt-in feature modules built on top of it (NexusKit.Modules), and a server for plugins that need one (NexusSyncServer). Together they aim to give Dalamud plugin authors a sturdy, batteries-included foundation — composition, persistence, UI, IPC, game-data lookups, chat notifications, ready-made integrations with community sources like Lodestone and FFXIVCollect, and a way to store and load data off the client without writing a backend from scratch.

## Projects

| Project | What it is |
|---|---|
| [**NexusKit**](https://github.com/NexusFFXIV/NexusKit) | Plugin-agnostic framework. Eight libraries: `Core`, `Persistence`, `Hosting`, `Ui`, `Ipc`, `GameData`, `ChatNotifications`, `Sync`. |
| [**NexusKit.Modules**](https://github.com/NexusFFXIV/NexusKit.Modules) | Reusable feature modules: `InternalData`, `ExternalData`, `PlayerEnrichment`, plus external bridges to `FFXIVCollect`, `Lodestone`, `PluginBridge`, and `Sync`. |
| [**NexusSyncServer**](https://github.com/NexusFFXIV/NexusSyncServer) | Server side of the sync stack. A plugin declares a **contract** — a JSON document naming its datasets and their direction — and registering it provisions storage, endpoints and permissions, so the common case needs no server code. Ships as a Docker image with a component kit for building your own admin pages. Every author runs their own; there is no shared instance. |
| [**DalamudRepo**](https://github.com/NexusFFXIV/DalamudRepo) | Custom Dalamud plugin repository. Hosts our own plugins **and** curates a mirror of third-party Dalamud repos — five scoped manifests (NexusFFXIV-only, individual third-party imports, curated third-party repos, auto-discovered third-party repos, plus a deduped union). The single URL players subscribe to. |

## Plugins

Dalamud plugins built on NexusKit + NexusKit.Modules. Each plugin is a self-contained consumer of the framework — they share infrastructure but no plugin state.

| Plugin | Status | What it does |
|---|---|---|
| [**PlayerNexusTracker**](https://github.com/NexusFFXIV/PlayerNexusTracker) | Active | Tracks players you meet — local session observation plus optional Lodestone / FFXIVCollect enrichment. |
| _Your plugin here_ | — | Building on NexusKit? Open a PR against [`NexusFFXIV/.github`](https://github.com/NexusFFXIV/.github) to add it. |

## Install plugins (as a player)

Plugins built under NexusFFXIV ship through a custom Dalamud repo. In Dalamud:

1. Open **Settings → Experimental → Custom Plugin Repositories**.
2. Paste:
   ```
   https://raw.githubusercontent.com/NexusFFXIV/DalamudRepo/main/pluginmaster.json
   ```
3. Save, then install plugins via `/xlplugins` → **All Plugins**.

Testing/Beta builds: tick **Settings → Experimental → Get plugin testing builds**. Stable users continue to see only stable releases.

Source of the repo manifest: [NexusFFXIV/DalamudRepo](https://github.com/NexusFFXIV/DalamudRepo).

## Install packages (as a plugin author)

All NexusKit, NexusKit.Modules and NexusSyncServer packages are published to GitHub Packages under this org:

```
https://nuget.pkg.github.com/NexusFFXIV/index.json
```

GitHub Packages requires authentication even for public packages. Configure a `nuget.config` in your consumer project with a personal access token that has the `read:packages` scope. See each project's README for ready-to-paste snippets.

Running a server needs no packages at all — the container image is published to GHCR as `ghcr.io/nexusffxiv/nexussyncserver`. The NexusSyncServer packages are only for authors composing their own image with extra modules.

## License

Everything in this org is released under **AGPL-3.0-only**. Contributions are welcome under the same license — derivative works and redistribution must remain open.
