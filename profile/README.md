<p align="center">
  <img src="https://raw.githubusercontent.com/usepons/kernel/main/logo/color.svg" width="80" alt="Pons Logo" />
</p>
<h1 align="center">Pons</h1>
<p align="center">
  <strong>A modular microkernel platform for building thinking systems.</strong><br/>
  <em>Compose intelligent agents from isolated, interchangeable modules.</em>
</p>
<p align="center">
  <a href="https://github.com/usepons/kernel"><img src="https://img.shields.io/github/stars/usepons/kernel?style=flat-square&logo=github&label=kernel&color=1d3557" alt="Kernel stars"/></a>
  <a href="https://jsr.io/@pons/kernel"><img src="https://jsr.io/badges/@pons/kernel?style=flat-square" alt="JSR @pons/kernel"/></a>
  <a href="https://jsr.io/@pons/sdk"><img src="https://jsr.io/badges/@pons/sdk?style=flat-square" alt="JSR @pons/sdk"/></a>
  <img src="https://img.shields.io/badge/runtime-Deno-black?style=flat-square&logo=deno" alt="Deno"/>
  <img src="https://img.shields.io/badge/language-TypeScript-3178c6?style=flat-square&logo=typescript" alt="TypeScript"/>
  <img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="MIT License"/>
</p>


## What is Pons?
**Pons** is a microkernel platform that runs intelligent modules as isolated processes, coordinated through a central kernel via IPC. Think of it as a minimal, composable OS for AI-powered systems — where every capability is a module, nothing is hardcoded, and the kernel stays thin.
> *"The smallest seed of a thinking system."*
Modules never import each other directly. All communication — events, RPC calls, config updates — flows through the kernel. This makes the system hot-swappable, observable, and easy to extend.
---
## Architecture
```
┌──────────────────────────────────────────────────────┐
│                        Kernel                        │
│                                                      │
│   ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │
│   │  Message Bus │  │   Lifecycle  │  │ Service   │  │
│   │  (pub/sub)   │  │   Manager   │  │ Directory │  │
│   └──────┬──────┘  └──────┬───────┘  └─────┬─────┘  │
└──────────┼───────────────┼────────────────┼─────────┘
           │               │                │
      ┌────┴──┐       ┌────┴───┐      ┌────┴────┐
      │ Agent │       │  LLM   │      │ Gateway │  ...
      └───────┘       └────────┘      └─────────┘
       process          process         process
```
Modules communicate only through the kernel. Hot-swap, restart, and discovery are built in.

---
## Repositories
| Repository | Description |
|---|---|
| [**kernel**](https://github.com/usepons/kernel) | The microkernel — message bus, lifecycle manager, RPC routing, service directory, config |
| [**sdk**](https://github.com/usepons/sdk) | TypeScript SDK for building Pons modules — base class, types, utilities |
| [**cli**](https://github.com/usepons/cli) | CLI tool to install, manage, and operate your Pons system |
| [**module-gateway**](https://github.com/usepons/module-gateway) | HTTP REST + WebSocket gateway module |
| [**module-llm**](https://github.com/usepons/module-llm) | Multi-provider LLM module (OpenAI, Anthropic, and more) |
| [**module-agent**](https://github.com/usepons/module-agent) | Agent runtime module for autonomous task execution |
| [**web**](https://github.com/usepons/web) | Web interface for the Pons platform |
---
## Getting Started
### Installation
You can install Pons using the automated install scripts, which will handle Deno installation if needed:

**For macOS and Linux:**
```sh
curl -fsSL https://raw.githubusercontent.com/usepons/.github/main/install.sh | sh
```

**For Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/usepons/.github/main/install.ps1 | iex
```

Alternatively, install Pons via the CLI directly (requires [Deno](https://deno.com)):
```sh
deno install -gA -n pons jsr:@pons/cli
```

### Quick Start
Once installed, start your Pons system:
```sh
pons install && pons onboard
```

To build your own module, use the SDK:
```sh
# deno.json
{
  "imports": {
    "@pons/sdk": "jsr:@pons/sdk@^0.2"
  }
}
```
```ts
import { ModuleRunner } from "@pons/sdk";
import type { ModuleManifest } from "@pons/sdk";

class MyModule extends ModuleRunner {
  readonly manifest: ModuleManifest = {
    id: "my-module",
    name: "My Module",
    description: "Does something useful",
    subscribes: ["some.topic"],
  };

  protected override async onMessage(topic: string, payload: unknown) {
    this.log("info", `Received: ${topic}`);
  }
}

new MyModule().start();
```
---
## Core Concepts

**Message Bus** — Modules publish and subscribe to topics. The kernel routes messages. No persistence, no retry — pure fire-and-forget.

**RPC** — Request/response calls between modules go through the kernel's service directory. The kernel resolves service names to module IDs and routes responses back with a 30s timeout.

**Module Lifecycle** — Each module runs as an isolated child process. The kernel handles spawn, kill, restart with exponential backoff, and hot-swap.

**Service Directory** — Modules declare what they `provides` and `requires`. The kernel ensures dependencies are satisfied before a module activates.

**Configuration** — Layered YAML config at `~/.pons/config.yaml`. Modules own a config section. Hot-reload via `SIGUSR1`.

---
## Contributing

All repositories follow the same contribution guidelines. See [CONTRIBUTING.md](https://github.com/usepons/kernel/blob/main/CONTRIBUTING.md) in the kernel repo to get started.

---
<p align="center">
  <sub>Built with 🖤 by <a href="https://cyberwolf.studio/">CyberWolf.Studio</a> · Powered by Deno · MIT Licensed</sub><br/>
  <sub>© 2026 Pons · <a href="https://github.com/usepons">github.com/usepons</a></sub>
</p>