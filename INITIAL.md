## FEATURE:

* **Infrastructure-as-Code (IaC) with Terraform (end-to-end)**

  * Provision everything needed for the backend and the website chatbot widget:

    * **Agents for Amazon Bedrock** with **Actions** (OpenAPI-defined) to call a **“Create Zendesk Ticket”** Lambda tool.
    * **Amazon Bedrock Knowledge Bases** using **Amazon S3 Vectors** as the vector store, with two S3-hosted CSV sources:

      1. web-scraped docs, 2) curated articles distilled from historical support emails.
    * **AWS Lambda functions**:

      * `zendesk_create_ticket` (called by Bedrock Action Group)
      * `lex_fulfillment` (callable from Lex/Connect flows now or later)
    * **Amazon API Gateway (HTTP API)** to front an `invoke-agent` passthrough Lambda for the web widget.
    * **Amazon Connect scaffolding (future-ready)** created and/or imported via Terraform:

      * Instance, Contact Flows, Lambda permission wiring, and Lex V2 bot association — so Connect omni-channels can call the same Lambdas even if the first release only ships the website widget. ([Terraform Registry][1], [AWS Documentation][2])
    * **IAM** roles/policies, **AWS Secrets Manager** (Zendesk secrets), **CloudWatch Logs**, and minimal **VPC** egress if needed for outbound Zendesk calls.
  * **Versioning & Backends**:

    * Use Terraform **v1.13.x** (current series) and **AWS provider v6.x** with provider lock files; remote state in **S3 backend** with the **S3 lockfile** (`use_lockfile = true`). DynamoDB-based state locking is **deprecated** for the S3 backend. ([HashiCorp Developer][3], [GitHub][4])

* **Website Chatbot Widget**

  * Lightweight JS widget that:

    * Starts a session (anonymous or JWT), streams responses from **Bedrock `InvokeAgent`** via our API, and renders citations/snippets from the Knowledge Base.
    * Offers a “Create Zendesk Ticket” button that triggers the Bedrock Action → Lambda → Zendesk flow.
  * (Optional for later) Provide an alternate “Route to live agent” button that opens **Amazon Connect Web Chat** when you enable it, using the Amazon Connect hosted widget or ChatJS. ([AWS Documentation][5], [GitHub][6])

* **Bedrock Agent with Actions → Zendesk Ticket Tool**

  * Action Group defined by an **OpenAPI schema** (`POST /support/tickets`) that maps to the `zendesk_create_ticket` Lambda. The Agent will elicit parameters (email, subject, description, tags, priority, plugin version, Mule runtime version) and call the action. ([AWS Documentation][7])
  * Runtime integration via **`InvokeAgent`** (our API calls it; web widget streams responses). ([AWS Documentation][8])

* **Knowledge Base (RAG) on S3 Vectors**

  * Build a **Knowledge Base** that ingests two CSVs from S3 (one for web scrapes, one for curated email articles). Bedrock handles chunking/embeddings and stores vectors in **S3 Vector buckets** (preview). ([AWS Documentation][9])

* **Zendesk Ticket Creation (API)**

  * Securely call Zendesk’s **Ticketing API** with API token auth, create a ticket, and set metadata (tags, custom fields). Use Basic auth header with `email/token:api_token` (Base64). If you need a deterministic **external\_id**, set it via update after creation to ensure idempotency. ([Zendesk Developer Docs][10])

* **Continuous Delivery for IaC**

  * Terraform project with pinned versions, provider lock file, **remote state**, CI checks (fmt/validate/plan), and guarded `apply` using OIDC-based AWS credentials. Include **tfenv** instructions for local version pinning. ([GitHub][11], [HashiCorp Developer][12])

## EXAMPLES:

In the `examples/` folder, add a README describing the flow and how to run locally. Include these templates/snippets (do not copy-paste credentials):

* `examples/terraform/project-structure.txt`

  ```
  infra/
    terraform/
      envs/
        dev/
          backend.hcl
          main.tf
          versions.tf
          variables.tf
          outputs.tf
        prod/
          ...
      modules/
        bedrock_agent/
        kb_s3_vectors/
        api_gateway_invoke_agent/
        lambda_zendesk_create_ticket/
        lambda_lex_fulfillment/
        connect_scaffold/   # optional now, useful later
        iam/
        observability/
  ```

  * `versions.tf` (pin to major/minor & lock providers):

    ```hcl
    terraform {
      required_version = ">= 1.13.0, < 2.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.11"
        }
      }
    }
    ```

    Commit `.terraform.lock.hcl`. Use S3 backend with lockfile:

    ```hcl
    terraform {
      backend "s3" {
        bucket       = "nova-terraform-state"
        key          = "mulesoft-ddog-support/${env}/tfstate"
        region       = "us-east-1"
        use_lockfile = true
      }
    }
    ```

    (DynamoDB locking is deprecated for the S3 backend.) ([HashiCorp Developer][3])

* `examples/terraform/modules/bedrock_agent/openapi/zendesk.yaml` (Action Group schema excerpt)

  ```yaml
  openapi: 3.0.1
  info: { title: Zendesk Ticket API, version: "1.0.0" }
  paths:
    /support/tickets:
      post:
        summary: Create a Zendesk ticket
        operationId: createZendeskTicket
        requestBody:
          required: true
          content:
            application/json:
              schema:
                type: object
                required: [requester_email, subject, description]
                properties:
                  requester_email: { type: string, format: email }
                  subject: { type: string }
                  description: { type: string }
                  priority: { type: string, enum: [low, normal, high, urgent] }
                  tags: { type: array, items: { type: string } }
                  plugin_version: { type: string }
                  mule_runtime: { type: string }
        responses:
          "200": { description: Ticket created }
  ```

  Wire this schema into a **Bedrock Action Group** that executes the `zendesk_create_ticket` Lambda. ([AWS Documentation][13])

* `examples/lambda/zendesk_create_ticket/index.ts` (sketch)

  ```ts
  import fetch from "node-fetch";
  const ZD_SUBDOMAIN = process.env.ZD_SUBDOMAIN!;
  const ZD_AUTH_B64  = process.env.ZD_AUTH_B64!; // base64("email/token:api_token")

  export const handler = async (event:any) => {
    const body = JSON.parse(event.body ?? "{}"); // from Bedrock Action
    const payload = {
      ticket: {
        requester: { email: body.requester_email },
        subject: body.subject,
        comment: { body: body.description },
        priority: body.priority ?? "normal",
        tags: body.tags ?? []
      }
    };
    const res = await fetch(`https://${ZD_SUBDOMAIN}.zendesk.com/api/v2/tickets.json`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${ZD_AUTH_B64}`
      },
      body: JSON.stringify(payload)
    });
    const json = await res.json();
    // Optional deterministic idempotency:
    // await fetch(`https://${ZD_SUBDOMAIN}.zendesk.com/api/v2/tickets/${json.ticket.id}.json`, {
    //   method: "PUT", headers: {...}, body: JSON.stringify({ ticket: { external_id: body.external_id } })
    // });
    return { statusCode: 200, body: JSON.stringify({ ticket_id: json.ticket.id }) };
  }
  ```

  Auth format and create/update endpoints per Zendesk docs. Store `ZD_AUTH_B64` in Secrets Manager and inject via Lambda env. ([Zendesk Developer Docs][14])

* `examples/lambda/lex_fulfillment/index.ts`
  Minimal handler that receives Lex V2 input event, calls internal services (or Bedrock if desired), and returns a fulfillment message. Include note on Lex V2 event/response shapes. ([AWS Documentation][15])

* `examples/api/gateway_invoke_agent.ts`
  A handler that calls **Bedrock `InvokeAgent`** (streaming) using the sessionId from the widget. ([AWS Documentation][16])

* `examples/web/widget/`

  * `widget.js` — tiny, framework-free snippet that mounts a chat bubble, opens a panel, and `fetch()`es from the API Gateway endpoint; supports SSE/streaming to render tokens as they arrive; includes a **“Create Zendesk Ticket”** UX that simply asks the agent to file a ticket (letting the agent’s **Action** handle the tool call).
  * A README that shows how to later swap to **Amazon Connect’s hosted widget** or **ChatJS** for live-agent handoff. ([AWS Documentation][5], [GitHub][6])

* `examples/kb/csv/`

  * `web_docs.csv` and `curated_articles.csv` header examples and a short note on uploading to S3 and attaching as Knowledge Base data sources for **S3 Vectors**. ([AWS Documentation][9])

* `examples/ci/`

  * GitHub Actions (or CodeBuild) workflow that runs `terraform fmt -check`, `terraform validate`, `tflint`, `terraform plan` on PR, then gated `apply` on main with OIDC AWS auth.

## DOCUMENTATION:

* **Terraform (versions, backends, locks, best practices)**

  * S3 backend and **S3 lockfile**; DynamoDB locking **deprecated** for S3 backend: https: developer.hashicorp.com/terraform/language/backend/s3 (see “State Locking”). ([HashiCorp Developer][3])
  * Provider dependency lock file (`.terraform.lock.hcl`): https: developer.hashicorp.com/terraform/language/files/dependency-lock. ([HashiCorp Developer][17])
  * Versioning and provider pinning tutorial: https: developer.hashicorp.com/terraform/tutorials/configuration-language/provider-versioning. ([HashiCorp Developer][12])
  * Recommended practices: https: developer.hashicorp.com/terraform/cloud-docs/recommended-practices. ([HashiCorp Developer][18])
  * Style guide: https: developer.hashicorp.com/terraform/language/style. ([HashiCorp Developer][19])
  * Terraform releases (CLI): https: github.com/hashicorp/terraform/releases (confirm latest stable). ([GitHub][20])
  * AWS provider releases (v6.x): https: github.com/hashicorp/terraform-provider-aws/releases. ([GitHub][4])
  * Optional local version manager: **tfenv**. ([GitHub][11])

* **Amazon Bedrock Agents & Knowledge Bases**

  * Define Actions (OpenAPI) for Action Groups: https: docs.aws.amazon.com/bedrock/latest/userguide/agents-api-schema.html, https: docs.aws.amazon.com/bedrock/latest/userguide/action-define.html. ([AWS Documentation][7])
  * Invoke an Agent (runtime): https: docs.aws.amazon.com/bedrock/latest/userguide/agents-invoke-agent.html and API reference. ([AWS Documentation][8])
  * Knowledge Bases + **S3 Vectors** overview and getting started: https: docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-create.html; https: docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-bedrock-kb.html; https: docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-getting-started.html. ([AWS Documentation][9])

* **Amazon Connect / Lex (for future omni-channels)**

  * Add chat widget to website; ChatJS library: https: docs.aws.amazon.com/connect/latest/adminguide/add-chat-to-website.html; https: github.com/amazon-connect/amazon-connect-chatjs. ([AWS Documentation][5], [GitHub][6])
  * Start chats via API & general chat docs: https: docs.aws.amazon.com/connect/latest/adminguide/integrate-with-startchatcontact-api.html; https: docs.aws.amazon.com/connect/latest/APIReference/chat-api.html. ([AWS Documentation][21])
  * Invoke Lambda in flows: https: docs.aws.amazon.com/connect/latest/adminguide/invoke-lambda-function-block.html. ([AWS Documentation][22])
  * Add a Lex V2 bot to Connect; Lex Lambda fulfillment & event/response formats: https: docs.aws.amazon.com/connect/latest/adminguide/amazon-lex.html; https: docs.aws.amazon.com/lexv2/latest/dg/intent-fulfillment.html; https: docs.aws.amazon.com/lexv2/latest/dg/lambda-input-format.html; https: docs.aws.amazon.com/lexv2/latest/dg/lambda-response-format.html. ([AWS Documentation][2])

* **Zendesk Ticketing**

  * Tickets API & quick start; API authentication; API token usage format `email/token:api_token`:
    https: developer.zendesk.com/api-reference/ticketing/tickets/tickets/;
    https: developer.zendesk.com/documentation/ticketing/getting-started/zendesk-api-quick-start/;
    https: developer.zendesk.com/documentation/api-basics/authentication/using-the-api-with-2-factor-authentication-enabled/. ([Zendesk Developer Docs][10])
  * External ID guidance (set via **Update Ticket**): https: support.zendesk.com/hc/en-us/articles/4408819890330-How-do-I-set-an-external-ID-of-a-Zendesk-Support-ticket. ([Zendesk Support][23])

## OTHER CONSIDERATIONS:

* **“Latest versions” done safely**

  * Pin **CLI** to `>= 1.13,<2.0` and **AWS provider** to the latest minor series (e.g., `~> 6.11` at the time of writing), and **commit** `.terraform.lock.hcl` so upgrades are deliberate. Use **tfenv** locally to match versions. ([HashiCorp Developer][17], [GitHub][11])

* **Terraform backend & locking**

  * Use S3 backend with **`use_lockfile = true`**. Note: **DynamoDB locking is deprecated** for S3 backend in current docs — prefer the S3 lockfile. Enable bucket **Versioning** and strict IAM on `*.tflock`. ([HashiCorp Developer][3])

* **State & environments**

  * Separate state per env (`envs/dev`, `envs/prod`), distinct S3 keys and prefixes. Avoid creating/destroying Amazon Connect instances repeatedly due to provider/API constraints; prefer one instance per env and import existing if needed. ([Terraform Registry][1])

* **Amazon Connect & Lex via Terraform**

  * The AWS provider supports many Connect resources and Lex V2 models, but certain edges can be tricky (e.g., queues/modules lifecycles, Lex alias wiring). Plan imports and avoid destroy-recreate churn. Keep Connect optional for v1, but scaffold module for future switch-on. ([Terraform Registry][1], [HashiCorp Discuss][24], [GitHub][25])

* **S3 Vectors Preview**

  * **Amazon S3 Vectors** (used by Bedrock Knowledge Bases) is in **preview**; check region availability and watch for API changes. Keep the CSV format simple (title, url, body, tags). ([AWS Documentation][26])

* **Zendesk robustness**

  * Use API token auth and rotate tokens via Secrets Manager. For idempotency, set a deterministic `external_id` **after** create (per Zendesk guidance) and/or upsert using search by `external_id`. Handle rate limits gracefully. ([Zendesk Developer Docs][14], [Zendesk Support][23])

* **Security & operations**

  * Use OIDC for CI to assume AWS roles (no long-lived keys). Least-privilege IAM for Lambdas and Bedrock. Log Bedrock **trace** for debugging. Never log secrets or full Zendesk tokens. Follow Terraform security practices for state access and provider verification. ([AWS Documentation][27], [HashiCorp | An IBM Company][28])

* **Widget & API concerns**

  * CORS: restrict origins to your site. Stream responses from `InvokeAgent` for snappy UX. Provide a fallback “email us” path if the Action fails. ([AWS Documentation][8])

* **Docs as code**

  * Keep `examples/` READMEs short and runnable. Include a `project-structure` map and `Makefile` targets for `fmt/validate/plan/apply/destroy`.

* **Env/config artifacts to include**

  * `.env.example` (for local widget/dev server only), Terraform `backend.hcl` templates, and `README` setup with:

    * How to obtain Zendesk token & format auth header (`email/token:api_token`, Base64). ([Zendesk Support][29])
    * How to upload CSVs to S3 and attach to KB.
    * How to run `tfenv install` and `terraform init` safely.

---

[1]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/connect_instance?utm_source=chatgpt.com "aws_connect_instance | Resources | hashicorp/aws | Terraform"
[2]: https://docs.aws.amazon.com/connect/latest/adminguide/amazon-lex.html?utm_source=chatgpt.com "Add an Amazon Lex bot to Amazon Connect"
[3]: https://developer.hashicorp.com/terraform/language/backend/s3 "Backend Type: s3 | Terraform | HashiCorp Developer"
[4]: https://github.com/hashicorp/terraform-provider-aws/releases?utm_source=chatgpt.com "Releases · hashicorp/terraform-provider-aws"
[5]: https://docs.aws.amazon.com/connect/latest/adminguide/add-chat-to-website.html?utm_source=chatgpt.com "Add a chat user interface to your website hosted by Amazon Connect"
[6]: https://github.com/amazon-connect/amazon-connect-chatjs?utm_source=chatgpt.com "Amazon Connect ChatJS - a browser-based contact center ..."
[7]: https://docs.aws.amazon.com/bedrock/latest/userguide/agents-api-schema.html?utm_source=chatgpt.com "Define OpenAPI schemas for your agent's action groups in ..."
[8]: https://docs.aws.amazon.com/bedrock/latest/userguide/agents-invoke-agent.html?utm_source=chatgpt.com "Invoke an agent from your application - Amazon Bedrock"
[9]: https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-create.html?utm_source=chatgpt.com "Create a knowledge base by connecting to a data source in ..."
[10]: https://developer.zendesk.com/api-reference/ticketing/tickets/tickets/?utm_source=chatgpt.com "Tickets"
[11]: https://github.com/tfutils/tfenv?utm_source=chatgpt.com "tfutils/tfenv: Terraform version manager"
[12]: https://developer.hashicorp.com/terraform/tutorials/configuration-language/provider-versioning?utm_source=chatgpt.com "Lock and upgrade provider versions | Terraform"
[13]: https://docs.aws.amazon.com/bedrock/latest/APIReference/API_agent_CreateAgentActionGroup.html?utm_source=chatgpt.com "CreateAgentActionGroup - Amazon Bedrock"
[14]: https://developer.zendesk.com/documentation/api-basics/authentication/using-the-api-with-2-factor-authentication-enabled/?utm_source=chatgpt.com "Using the API when SSO or two-factor authentication is ..."
[15]: https://docs.aws.amazon.com/lexv2/latest/dg/lambda-input-format.html?utm_source=chatgpt.com "AWS Lambda input event format for Lex V2"
[16]: https://docs.aws.amazon.com/bedrock/latest/userguide/bedrock-agent-runtime_example_bedrock-agent-runtime_InvokeAgent_section.html?utm_source=chatgpt.com "Use InvokeAgent with an AWS SDK - Amazon Bedrock"
[17]: https://developer.hashicorp.com/terraform/language/files/dependency-lock?utm_source=chatgpt.com "Dependency Lock File - Terraform"
[18]: https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices?utm_source=chatgpt.com "Learn Terraform recommended practices"
[19]: https://developer.hashicorp.com/terraform/language/style?utm_source=chatgpt.com "Style Guide - Configuration Language | Terraform"
[20]: https://github.com/hashicorp/terraform/releases?utm_source=chatgpt.com "Releases · hashicorp/terraform - GitHub"
[21]: https://docs.aws.amazon.com/connect/latest/adminguide/integrate-with-startchatcontact-api.html?utm_source=chatgpt.com "Start chats in your applications by using Amazon Connect APIs"
[22]: https://docs.aws.amazon.com/connect/latest/adminguide/invoke-lambda-function-block.html?utm_source=chatgpt.com "Flow block in Amazon Connect: AWS Lambda function"
[23]: https://support.zendesk.com/hc/en-us/articles/4408819890330-How-do-I-set-an-external-ID-of-a-Zendesk-Support-ticket?utm_source=chatgpt.com "How do I set an external ID of a Zendesk Support ticket?"
[24]: https://discuss.hashicorp.com/t/terraform-can-not-destroy-an-aws-connect-instance-stack/64576?utm_source=chatgpt.com "Terraform can not destroy an aws connect instance stack"
[25]: https://github.com/hashicorp/terraform-provider-aws/issues/36044?utm_source=chatgpt.com "Lex v2 alias support · Issue #36044 · hashicorp/terraform- ..."
[26]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-getting-started.html?utm_source=chatgpt.com "Tutorial: Getting started with S3 Vectors - AWS Documentation"
[27]: https://docs.aws.amazon.com/bedrock/latest/APIReference/API_agent-runtime_InvokeAgent.html?utm_source=chatgpt.com "InvokeAgent - Amazon Bedrock"
[28]: https://www.hashicorp.com/en/blog/terraform-security-5-foundational-practices?utm_source=chatgpt.com "Terraform security: 5 foundational practices"
[29]: https://support.zendesk.com/hc/en-us/articles/4408831452954-How-can-I-authenticate-API-requests?utm_source=chatgpt.com "How can I authenticate API requests?"
