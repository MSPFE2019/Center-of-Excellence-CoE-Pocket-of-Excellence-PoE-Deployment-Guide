**Center of Excellence (CoE) & Pocket of Excellence (PoE) Deployment Guide**


*Pre-Installation Checklists • Scope, Capabilities & Limitations*

---

## 1. Introduction

This consolidated document provides:

1. **Pre-Installation (“Pre-Flight”) Checklists** for both a tenant-wide **Center of Excellence (CoE)** and an agency-scoped **Pocket of Excellence (PoE)**.
2. A detailed **comparison** of CoE vs. PoE—outlining what PoE cannot do relative to CoE—to guide deployment and governance decisions.

---

## 2. Pre-Installation (“Pre-Flight”) Checklists

### 2.1 Center of Excellence (CoE)

| Item                            | Requirement                                                                                                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Service Account**             | • **Role**: Power Platform Admin<br>• **Licenses**: Power Apps Per User (non-trial), Power Automate Per User (non-trial), Microsoft 365<br>• **Identity**: Email-enabled |
| **Standard User Setup (G1–G5)** | • All standard users must be assigned G1–G5 licenses                                                                                                                     |
| **Dedicated CoE Environment**   | • Power Platform environment with Dataverse enabled                                                                                                                      |

#### Optional Components

* **Power Platform Maker Microsoft 365 Group**
  Identify or create the Makers group—auto-populated via **Admin | Add Maker to Group** flow.
  *If enabled*, CoE will enumerate all tenant users to provision environments (excludes Power BI).

* **Azure Tenant ID**
  Provided by central IT.

* **Azure App Registration**
  Required for custom connectors or service-to-service authentication.

* **Message Center Integration**
  Grant “Allow Command Center apps to get Message Center updates.”

* **Audit-Log Collection**
  Use the HTTP action per Microsoft Learn’s “Power Platform audit logs.”

* **Community URL**
  Link to internal hub (e.g., Yammer or Teams). Required by **Admin | Welcome Email v3**.

* **Power BI Workspace**
  Must be licensed or per-user licensed. (G5 licenses include Power BI entitlement.)

---

### 2.2 Pocket of Excellence (PoE)

| Item                            | Requirement                                                                                                                                                                      |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Service Account**             | • **Role**: Environment Admin on **all** agency PoE environments<br>• **Licenses**: Power Apps Per User, Power Automate Per User, Microsoft 365<br>• **Identity**: Email-enabled |
| **Standard User Setup (G1–G5)** | • Service account must be **Owner** of **all** agency Teams (to pull Teams data into Dataverse)                                                                                  |
| **Dedicated PoE Environment**   | • Power Platform environment with Dataverse enabled<br>• Service account as Environment Admin                                                                                    |

#### Optional Components

* **Power Platform Maker Microsoft 365 Group**
  Identify or create the Makers group—auto-populated via **Admin | Add Maker to Group** flow.

* **Azure Tenant ID**
  Provided by central IT.

* **Azure App Registration**
  For scoped service-to-service scenarios.

* **Message Center Integration**
  Grant the necessary Message Center update permissions.

* **Community URL**
  Link to internal hub for **Admin | Welcome Email v3**.

* **Power BI Workspace**
  Same licensing requirements as CoE.

---

## 3. Center of Excellence vs. Pocket of Excellence

### 3.1 Definitions

* **CoE**: Tenant-level governance, automation, analytics, and policy enforcement across **all** environments and users.
* **PoE**: Agency-scoped subset of CoE functionality, limited to specific environments and users within a shared tenant.

### 3.2 Capability Gaps

| Category                      | Capability                                     | CoE Supported |     PoE Supported?     | Validation (Microsoft Docs)                                                |                                                    |
| ----------------------------- | ---------------------------------------------- | :-----------: | :--------------------: | -------------------------------------------------------------------------- | -------------------------------------------------- |
| **Provisioning & Automation** | Auto-provision environments for all Makers     |       ✔       | ✖ (Only scoped Makers) | CoE data model supports environment request ([Microsoft Learn][1])         |                                                    |
|                               | Global user enumeration & environment creation |       ✔       |            ✖           | Foundation: Dataverse collects across tenant ([Microsoft Learn][1])        |                                                    |
|                               | Command Center Message Center integration      |       ✔       |     ✖ (Agency only)    | Admin                                                                      | Deep dive on Message Center ([Microsoft Learn][2]) |
|                               | Tenant-wide audit-log collection               |       ✔       |    ✖ (Only PoE env.)   | Govern                                                                     | Audit & compliance features ([Microsoft Learn][2]) |
| **Visibility & Reporting**    | Tenant-wide usage analytics dashboards         |       ✔       |    ✖ (Agency scope)    | CoE Power BI reports overview ([Microsoft Learn][1])                       |                                                    |
|                               | Cross-environment Power BI reports             |       ✔       |  ✖ (Single workspace)  | CoE templates combine all env. data ([Microsoft Learn][1])                 |                                                    |
|                               | Tenant-level DLP & governance policies         |       ✔       |  ✖ (Local enforcement) | Govern                                                                     | DLP Editor & Customiser ([Microsoft Learn][2])     |
| **Administration & Roles**    | Platform-level role delegation                 |       ✔       |   ✖ (Env-Admin only)   | Requires service or global admin ([Microsoft Power Platform Community][3]) |                                                    |
|                               | Centralized Maker group management             |       ✔       |   ✖ (Own group only)   | Nurture                                                                    | Add Maker to Group flow ([Syskit][4])              |
|                               | Global service-to-service app registrations    |       ✔       |    ✓ (Scoped to PoE)   | App registration for audit logs ([Microsoft Power Platform Community][3])  |                                                    |

### 3.3 Limitations of PoE Relative to CoE

1. **Governance Scope**
   PoE cannot enforce or monitor policies outside its designated environment. CoE applies tenant-wide DLP, sensitivity labels, and compliance rules.

2. **Automation Reach**
   Flows such as environment provisioning or Maker enumeration operate only within PoE’s environments. CoE automates across **all** tenant environments.

3. **Analytics & Insights**
   PoE dashboards surface only agency-specific metrics. CoE provides holistic tenant-wide usage, adoption, and performance reporting.

4. **Message Center & Audit Logs**
   PoE ingests updates and logs solely for its environment. CoE integrates these streams across the entire tenant for comprehensive monitoring.

5. **Role Assignment**
   PoE service accounts hold **Environment Admin** rights only—insufficient for tenant-level settings managed by CoE’s **Power Platform Admin** role.

### 3.4 When to Choose PoE vs. CoE

* **Use PoE** if you need a lightweight, agency-scoped governance model without tenant-wide impact, focusing on localized reporting and enforcement.
* **Use CoE** when you require centralized governance, compliance, automation, and analytics across **all** Power Platform environments and users in the tenant.

---

## 4. Conclusion

While **Pocket of Excellence** provides targeted, agency-level oversight, it is inherently limited compared to a full **Center of Excellence**. For any requirement involving tenant-wide control, policy enforcement, provisioning, or analytics, a CoE implementation is necessary.

[1]: https://learn.microsoft.com/en-us/power-platform/guidance/coe/overview?utm_source=chatgpt.com "Power Platform Center of Excellence (CoE) Starter Kit ..."
[2]: https://learn.microsoft.com/en-us/power-platform/guidance/coe/starter-kit?utm_source=chatgpt.com "Microsoft Power Platform Center of Excellence Starter Kit"
[3]: https://community.powerplatform.com/forums/thread/details/?threadid=5ad7df11-ad99-47fa-b1ad-679d766d69cb&utm_source=chatgpt.com "Solved: Power Platform CoE Starter Kit"
[4]: https://www.syskit.com/blog/center-of-excellence-starter-kit/?utm_source=chatgpt.com "Power Platform Center of Excellence Starter Kit Explained"
