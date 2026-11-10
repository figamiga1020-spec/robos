# Technical Architecture — REALMS_OF_ETERNITY_REBUILD

## Environment reality
This rebuild was produced from a **filesystem-only** environment:
- No live Roblox Studio session
- No published Animation asset IDs
- No Blender mesh pipeline in this session

Therefore:
- All gameplay systems are implemented as **server-authoritative Luau**
- World geometry uses **coordinate layout + placeholder Parts** until Studio art pass
- Animations must be added in Studio (Animation Editor) or via Motor6D procedural layer later
- Enemy/boss models are temporary colored Parts with Humanoid (replace with rigs)

## Continuous world (no portals)
`WorldLayout.luau` defines Aurenholm and Eldoria bounds, gates, roads, and zones.
Players walk from Eastern Gate into Eldoria. Zone proximity drives `Reach` quest objectives.

## Vertical slice systems
| System | Path | Authority |
|--------|------|-----------|
| Data/Save | Services/DataService | Server + DataStore |
| Character create | Systems/Character | Server validates race/class |
| Combat + skills | Systems/Combat | Server damage/cooldowns |
| Inventory | Systems/Inventory | Server |
| Quests (5-chain) | Systems/Quest | Server |
| Party 1/2/3/5 | Systems/Party | Server + scale table |
| Enemies | Systems/Enemy | Server AI |
| Forest Guardian | Systems/Boss | Server phases + telegraphs |
| World/Death | Systems/World | Server respawn |

## Phase-1 playable classes only
Knight, Mage, Ranger, Assassin — full skill definitions.
Other 16 classes exist as architecture stubs with `IsPhase1Playable = false`.

## Import
Use Rojo with `default.project.json`, or copy ModuleScripts/Scripts into Studio matching folder layout.
Enable API Services for DataStore testing.
