# Architecture Overview

```mermaid
flowchart TD
    C[HTTP Client / PowerShell] --> R[router.php]
    R --> P[public/index.php]
    P --> H[Read Method + Headers + JSON Body]
    H --> A[ApiApplication]
    A --> V[Validation + Bearer Auth + HTTP Routing]
    V --> S[ItemRepository]
    S --> D[(storage/items.json)]
    A --> J[JSON Response + Request ID]
    P --> L[AuditLogger]
    L --> G[(storage/audit.jsonl)]
    J --> C
```

The public directory is the only web document root. Runtime storage and source classes remain outside it. The local built-in server router sends API paths to the front controller.
