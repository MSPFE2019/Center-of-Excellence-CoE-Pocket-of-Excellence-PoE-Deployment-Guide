// Paste each query into its own Power Query query.
// Replace ENVIRONMENT_URL with your Dataverse environment URL.

let
    Source = CommonDataService.Database("ENVIRONMENT_URL"),
    InventorySnapshot = Source{[Schema="dbo", Item="coe_inventorysnapshot"]}[Data]
in
    InventorySnapshot

let
    Source = CommonDataService.Database("ENVIRONMENT_URL"),
    InventorySnapshotItem = Source{[Schema="dbo", Item="coe_inventorysnapshotitem"]}[Data]
in
    InventorySnapshotItem

let
    Source = CommonDataService.Database("ENVIRONMENT_URL"),
    DriftFinding = Source{[Schema="dbo", Item="coe_driftfinding"]}[Data]
in
    DriftFinding

