# Power Platform COE Drift Detection Flow

Daily scheduled flow for GCC tenants.

## Flow goal

Capture a normalized snapshot of the tenant inventory, compare it to the prior successful snapshot, and write drift findings back to Dataverse.

## Required connectors

| Connector | Purpose |
|---|---|
| Recurrence | Daily trigger |
| HTTP | Power Platform admin API and Graph calls |
| Microsoft Dataverse | Store snapshots and findings |
| Data Operations | Parse JSON, filter arrays, compose hashes |

## Core runtime variables

| Name | Type | Purpose |
|---|---|---|
| `CloudName` | String | GCC, GCCHigh, or DoD |
| `PowerPlatformApiBaseUrl` | String | Admin API root |
| `GraphBaseUrl` | String | Graph root for owner checks |
| `CurrentSnapshotName` | String | Human-readable run name |
| `CurrentSnapshotDate` | String | UTC timestamp |
| `ComparisonLookbackDays` | Integer | How far back to search for the prior snapshot |

## Snapshot steps

1. Create an `Inventory Snapshot` row with status `Started`.
2. Query the Power Platform admin API for:
   - environments
   - apps
   - flows
   - solutions
   - custom connectors
   - connection references
   - connector/DLP metadata
3. Normalize each record into an `Inventory Snapshot Item` row.
4. Build a stable `Item Key` and `Fingerprint` for each row.
5. Retrieve the most recent prior successful snapshot for the same scope.
6. Compare current items to prior items.
7. Write `Drift Finding` rows for differences.
8. Update the snapshot row with counts and final status.

## Comparison rules

| Finding type | Trigger |
|---|---|
| New Item | Item exists today but not in the prior snapshot |
| Deleted Item | Item existed previously but not today |
| Owner Changed | Owner UPN changed between snapshots |
| Owner Left Org | Owner no longer resolves in Graph |
| Unmanaged Edit | Managed state or fingerprint changed on an unmanaged object |
| DLP Group Changed | Connector moved to a different DLP group |
| Blocked DLP Group | Connector moved into a blocked group |
| Shared With Everyone | App or flow is visible to Everyone / whole org |
| Permission Drift | Connections, references, or sharing changed materially |

## GCC endpoints

| Cloud | Power Platform admin API | Graph |
|---|---|---|
| GCC | `https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform` | `https://graph.microsoft.com/v1.0` |
| GCC High | `https://api.bap.appsplatform.us/providers/Microsoft.BusinessAppPlatform` | `https://graph.microsoft.us/v1.0` |
| DoD | `https://api.bap.appsplatform.us/providers/Microsoft.BusinessAppPlatform` | `https://dod-graph.microsoft.us/v1.0` |

