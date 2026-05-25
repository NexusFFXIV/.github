# NexusFFXIV

**Plugin framework and reusable modules for FINAL FANTASY XIV Dalamud plugins.**

NexusFFXIV is home to two related projects: a plugin-agnostic framework (NexusKit) and a set of opt-in feature modules built on top of it (NexusKit.Modules). Together they aim to give Dalamud plugin authors a sturdy, batteries-included foundation — composition, persistence, UI, IPC, game-data lookups, chat notifications, and ready-made integrations with community sources like Lodestone and FFXIVCollect.

## Projects

| Project | What it is |
|---|---|
| [**NexusKit**](https://github.com/NexusFFXIV/NexusKit) | Plugin-agnostic framework. Seven libraries: `Core`, `Persistence`, `Hosting`, `Ui`, `Ipc`, `GameData`, `ChatNotifications`. |
| [**NexusKit.Modules**](https://github.com/NexusFFXIV/NexusKit.Modules) | Reusable feature modules: `InternalData`, `ExternalData`, `PlayerEnrichment`, plus external bridges to `FFXIVCollect`, `Lodestone`, and `PluginBridge`. |
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

All NexusKit and NexusKit.Modules packages are published to GitHub Packages under this org:

```
https://nuget.pkg.github.com/NexusFFXIV/index.json
```

GitHub Packages requires authentication even for public packages. Configure a `nuget.config` in your consumer project with a personal access token that has the `read:packages` scope. See each project's README for ready-to-paste snippets.

## License

Everything in this org is released under **AGPL-3.0-only**. Contributions are welcome under the same license — derivative works and redistribution must remain open.
