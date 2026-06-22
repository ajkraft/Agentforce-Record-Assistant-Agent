# Agentforce Record Assistant Agent

A drop-in **Agentforce employee agent** that creates and updates Salesforce records on
request. It gives **Agentforce Coworker** a place to hand off record *writes*: Coworker does
the searching, research, and reasoning, and when the user asks it to *create* or *update*
something, it delegates to this agent, which performs the write and returns a link to the
record.

This closes a common gap as of June 22nd, 2026: out of the box, Coworker can find and reason over records but does
not have a built-in tool to create or update them. Deploy this agent and assign its
permission set, and Coworker gains reliable create/update capability across your objects.

## What it does

The agent exposes one topic, **Record Management**, backed by three Apex actions:

| Action | What it does |
| --- | --- |
| **Find Record** | Resolves a name (or partial name) to a record Id so lookups can be wired up before a write. |
| **Create Record** | Creates a new record of any standard or custom object from a JSON map of field values. |
| **Update Record** | Updates fields on an existing record by Id. |

A typical flow: the user asks to create a record that references another record by name. The
agent first calls **Find Record** to resolve each referenced name to its Id, then calls
**Create Record** with those Ids set on the appropriate lookup/relationship fields, and
finally returns a link to what it saved.

## How it works

- **Object-agnostic.** The Apex uses `Schema.getGlobalDescribe()` and dynamic SObject DML, so
  the same three actions work across standard and custom objects without per-object code.
- **Respects permissions.** All DML and SOQL run in **user mode**
  (`AccessLevel.USER_MODE`) and the classes are `with sharing`, so every operation honors the
  running user's CRUD, FLS, and sharing. Users can only create or update what they are
  already allowed to.
- **Safe by design.** The agent creates and updates only. It does **not** delete records, run
  mass updates, or run reports. Unknown fields in the input are skipped rather than failing
  the whole write, and unparseable input returns a clear message instead of throwing.

## What's included

```
force-app/main/default/
├── bots/Records_Assistant/              Agent (bot) + version definition
├── genAiPlannerBundles/Records_Assistant/   ReAct planner bundle
├── genAiPlugins/Record_Management...    Topic + instructions
├── genAiFunctions/                      Find_Record, Create_Record, Update_Record (+ schemas)
├── classes/                             RecordsAssistantUtil / Find / Create / Update (+ tests)
└── permissionsets/Records_Assistant_User...  Agent + Apex access
```

## Deploy

Requires the Salesforce CLI (`sf`) and an org with Agentforce / Einstein Copilot enabled.

```bash
# 1. Authorize your org (skip if already connected)
sf org login web --alias my-org

# 2. Deploy the metadata
sf project deploy start --source-dir force-app --target-org my-org

# 3. Assign the permission set to users who should use the agent
sf org assign permset --name Records_Assistant_User --target-org my-org
```

Then, in Setup → **Agentforce / Agents**, open **Records Assistant**, review the topic and
actions, and **activate** it. Once active and the permission set is assigned, Coworker can
delegate record creation and updates to it.

## Notes

- API version: 67.0. Namespace: none (unmanaged source).
- The included Apex tests use only transient, in-memory test data on standard objects, so the
  package meets the coverage required to deploy to production. No sample records are created
  in your org.
- This is a generic scaffold. Adjust the topic instructions, agent tone, and permission set
  to fit your org's objects, picklist values, and naming conventions.

## License

Released under the [MIT License](LICENSE).
