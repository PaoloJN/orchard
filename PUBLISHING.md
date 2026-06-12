# Publishing Orchard

Two steps: host the files so there's a one-line install, then list Orchard on
PineStore so it lives in its own catalog.

## 1. Host the files (GitHub — recommended)

Create a public repo whose layout mirrors the computer root:

```
<repo root>/
├── startup.lua
└── orchard/
    ├── orchard.lua
    ├── install.lua
    ├── lib/      (config, installer, log, pinestore, registry, ui)
    └── screens/  (browse, details, installed)
```

Then in `orchard/install.lua`, set:

```lua
local BASE = "https://raw.githubusercontent.com/paolojn/orchard/main"
```

(`main` = your default branch.) That makes the one-liner:

```
wget run https://raw.githubusercontent.com/paolojn/orchard/main/orchard/install.lua
```

Test it on a fresh CraftOS-PC computer before sharing. `install.lua` fetches
every file, creates `/apps`, and puts both on the shell path.

> Pastebin works too: paste `install.lua` (with `BASE` pointing at raw GitHub),
> and share `wget run https://pastebin.com/raw/<code>`. GitHub is easier to update.

## 2. List it on PineStore

Go to https://pinestore.cc, sign in with Discord, "Add project", and fill:

| Field             | Value                                                             |
|-------------------|------------------------------------------------------------------|
| Name              | Orchard                                                          |
| Short description | An app store for CraftOS, built on the PineStore catalog        |
| Install command   | `wget run https://raw.githubusercontent.com/paolojn/orchard/main/orchard/install.lua` |
| Target file       | `orchard/orchard.lua`                                            |
| Repository        | your GitHub URL                                                 |
| Tags / keywords   | utility, package-manager, store, pinestore                      |

Nice touch: once it's listed, Orchard can install **itself**, and it'll show up
when users search the store from inside Orchard.

## 3. The Discord post (ready to paste)

> **Orchard — an app store for CraftOS** 🌳
>
> Browse, search, and one-keypress-install community programs straight from the
> shell — no more hunting for `wget` links. It's a client for the PineStore
> catalog, so there are 150+ apps from day one. Everything installs into `/apps`
> and is runnable by name; it tracks what you've installed and flags updates.
>
> Install:
> ```
> wget run https://raw.githubusercontent.com/paolojn/orchard/main/orchard/install.lua
> ```
> then type `orchard`. Mouse + keyboard. Catalog & API by PineStore 🙏
>
> Feedback very welcome — what would you want it to do next?

Attach a short GIF of: open `orchard` → type to filter → `Enter` → `I` install →
run the app by name. (CraftOS-PC can record one, or screen-capture the window.)

## Cross-platform note

Orchard targets CC:Tweaked, so it also runs in Minecraft, not just CraftOS-PC.
The `keys.escape or 1` fallback handles both ROMs (CraftOS-PC leaves Esc
unmapped; real CC:Tweaked maps it). HTTP and `textutils.unserialiseJSON` are
standard in modern CC:Tweaked.
