# Agent Engine PSC Network Attachment & Cloud NAT Demo

This project demonstrates how a Google Cloud **Agent Engine** (Vertex AI Reasoning Engine) instance can securely communicate with both **Google APIs** and the **Public Internet** from a private environment using a Private Service Connect (PSC) Network Attachment, a Proxy VM, and Cloud NAT.

---

## What This Project Does

When deployed to Google Cloud Agent Engine, the agent runs in a managed service tenant network. By configuring a **PSC Network Attachment**, the agent's network interface is attached directly to your customer VPC (`attachment-vpc`).

To handle outbound traffic properly from the Agent Engine:

1. **Google APIs Egress (via PSC Endpoint)**:
   - Traffic targeting `googleapis.com` resolves via Private DNS to an internal Private Service Connect IP (`10.250.0.1`).
   - The agent reaches Google APIs privately inside the VPC without sending API traffic out to the public internet.

2. **Public Internet Egress (via Proxy VM & Cloud NAT)**:
   - Direct outbound internet connections from Agent Engine via network attachments require an explicit HTTP proxy inside the customer VPC.
   - A lightweight **Tinyproxy VM** (`proxy-vm`) is deployed in the customer VPC.
   - Environment variables (`HTTP_PROXY`, `HTTPS_PROXY`, `proxy_server`) route internet-bound requests from the agent to the Tinyproxy VM on port `8888`.
   - The Tinyproxy VM routes outbound traffic through **Cloud NAT** (`attachment-nat`) to access public internet endpoints (e.g. `api.ipify.org`).

3. **Proxy Bypass (`NO_PROXY`)**:
   - `NO_PROXY` is configured on the agent to ensure local GCE metadata server requests (`metadata.google.internal`, `169.254.169.254`), PSC Google APIs (`googleapis.com`, `10.250.0.1`), and VPC internal ranges bypass the HTTP proxy.

---

## Architecture & Communication Flow

```mermaid
graph TD
    subgraph AgentEngineTenant ["Agent Engine Service Tenant Network"]
        Agent ["ADK Agent Engine (Reasoning Engine)"]
    end

    subgraph CustomerVPC ["Customer VPC (attachment-vpc)"]
        Subnet ["Attachment Subnet (10.1.0.0/24)"]
        
        NA ["Network Attachment (agent-engine-network-attachment)"]
        
        PSCEndpoint ["PSC Google APIs Endpoint (10.250.0.1)"]
        DNS ["Private DNS Zone (googleapis.com -> 10.250.0.1)"]
        
        ProxyVM ["Proxy VM (proxy-vm: 10.1.0.4:8888)"]
        
        CloudNAT ["Cloud Router & Cloud NAT (attachment-nat)"]
    end

    subgraph External ["External Networks & Services"]
        GoogleAPIs ["Google APIs"]
        Internet ["Public Internet (e.g. api.ipify.org)"]
    end

    Agent -->|"1. Connects via PSC"| NA
    NA -->|"Enters Subnet"| Subnet

    Subnet -->|"2a. Google API Traffic (NO_PROXY)"| PSCEndpoint
    PSCEndpoint --> GoogleAPIs

    Subnet -->|"2b. Public Internet Traffic (HTTP_PROXY)"| ProxyVM
    ProxyVM -->|"3. Outbound Egress"| CloudNAT
    CloudNAT -->|"4. NAT External IP"| Internet
```

---

## Deployment & Usage

### 1. Provision Infrastructure with Terraform

```bash
cd tf
terraform init
terraform apply -auto-approve
```

### 2. Deploy Agent to Agent Engine

```bash
uv sync
uv pip freeze > aenat/requirements.txt
uv run adk deploy agent_engine aenat --project [projectid] --region us-east1
```
