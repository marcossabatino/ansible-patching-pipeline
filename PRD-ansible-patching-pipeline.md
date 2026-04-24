# PRD — ansible-patching-pipeline
## For Claude Code (terminal)

---

## Git Co-authorship — MANDATORY FIRST STEP

Before generating any file, configure the project to suppress Claude Code co-authorship from all commits:

```bash
# In the project root, after git init:
git config user.name "Marcos Sabatino"
git config user.email "your@email.com"

# Create Claude Code settings file to disable co-authorship
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "includeCoAuthoredBy": false
}
EOF
```

This file must be committed first. No commit in this repository should contain `Co-authored-by: Claude` in the message.

---

## Project Goal

Build an Ansible project that implements a **production-grade patch management pipeline** for Ubuntu EC2 instances. The pipeline follows the full operational cycle: pre-check → patch → conditional reboot → post-check → report.

This project is a public GitHub portfolio piece for a **Senior Ansible Automation Engineer** CV. It must demonstrate real operational thinking: safe pre-conditions, rollback awareness, environment-aware execution, and evidence of completion via rich reports.

---

## CV Claims This Project Validates

| CV Statement | Demonstrated by |
|---|---|
| "patching" | Full apt patch pipeline with pre/post checks |
| "reusable automation frameworks" | Role with `defaults/`, all params tunable, tag-based execution |
| "Ansible Tower / AAP" | Structure mirrors AAP Job Template + Survey; README explains mapping |
| "operational workflows" | Pre-check gates (disk space, critical services) that abort on failure |
| "standardize operational processes" | Consistent pipeline structure; same role applies to all environments |
| "mission-critical systems" | Configurable service exclusion list; reboot window enforcement |
| "compliance" | Reports with CVE summary, before/after package lists, audit trail |

---

## Terraform Reuse — IMPORTANT

**Do NOT recreate Terraform from scratch.** This project reuses Terraform from:

```
https://github.com/marcossabatino/ansible-linux-hardening
```

### Instructions for Claude Code:

```bash
# Clone the reference repo to extract Terraform
git clone https://github.com/marcossabatino/ansible-linux-hardening.git /tmp/hardening-ref

# Copy the terraform directory into the new project
cp -r /tmp/hardening-ref/terraform ./terraform

# Clean up
rm -rf /tmp/hardening-ref
```

### Required modifications to the copied Terraform:

1. **`terraform/variables.tf`** — Change defaults:
   - `project_name` default → `"patching-pipeline-lab"`
   - `managed_node_count` default → `2`
   - Add variable `environment` (string, default `"sandbox"`, description `"Target environment — controls patch aggressiveness"`)

2. **`terraform/main.tf`** — Change:
   - `local.common_tags`: keep all 4 `fo:` tags exactly as-is
   - `Project` value → `var.project_name`
   - Control node `user_data`: add `pip3 install boto3 botocore` after existing ansible install

3. **`terraform/outputs.tf`** — No changes needed.

4. **`terraform/inventory.tftpl`** — No changes needed.

---

## Directory Structure to Generate

```
ansible-patching-pipeline/
├── .claude/
│   └── settings.json              # Claude Code: co-authorship disabled
├── .gitignore
├── README.md
├── ansible.cfg
├── terraform/                     # Copied + adapted from ansible-linux-hardening
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── inventory.tftpl
├── inventory/
│   └── .gitkeep
├── group_vars/
│   ├── all.yml                    # Shared patching defaults
│   ├── sandbox.yml                # Overrides for sandbox (aggressive patching)
│   └── production.yml             # Overrides for production (conservative patching)
├── playbooks/
│   ├── patch.yml                  # Full pipeline: pre-check → patch → reboot → post-check → report
│   ├── pre_check.yml              # Pre-check only (standalone, safe to run anytime)
│   └── rollback.yml               # Emergency: pin packages back to last known good
├── roles/
│   └── patch_manager/
│       ├── defaults/
│       │   └── main.yml
│       ├── handlers/
│       │   └── main.yml
│       ├── meta/
│       │   └── main.yml
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── 1_pre_check.yml
│       │   ├── 2_snapshot.yml
│       │   ├── 3_patch.yml
│       │   ├── 4_reboot.yml
│       │   ├── 5_post_check.yml
│       │   └── 6_report.yml
│       └── templates/
│           ├── report.txt.j2
│           └── report.html.j2
└── reports/
    └── .gitkeep
```

---

## File-by-File Specifications

---

### `.claude/settings.json`

```json
{
  "includeCoAuthoredBy": false
}
```

---

### `.gitignore`

Exclude:
- `*.pem`, `*.key`
- `*.tfstate`, `*.tfstate.backup`, `.terraform/`, `.terraform.lock.hcl`, `terraform.tfvars`
- `inventory/hosts.ini`
- `reports/*.txt`, `reports/*.html`
- `__pycache__/`, `*.pyc`, `.venv/`
- `.DS_Store`
- `*.retry`

---

### `ansible.cfg`

```ini
[defaults]
inventory          = inventory/hosts.ini
roles_path         = roles
host_key_checking  = False
stdout_callback    = yaml
retry_files_enabled = False
remote_user        = ubuntu
private_key_file   = ~/.ssh/id_rsa

[privilege_escalation]
become       = True
become_method = sudo
become_user  = root
become_ask_pass = False

[ssh_connection]
pipelining   = True
ssh_args     = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
```

---

### `group_vars/all.yml`

Baseline patching defaults shared across all environments:

```yaml
---
# ── Pre-check thresholds ──────────────────────────────────────────
# Pipeline will ABORT if any of these conditions are not met.
min_disk_free_percent: 20       # Minimum free disk space on / required to proceed
min_memory_free_mb: 256         # Minimum free RAM in MB required to proceed

# ── Critical services — patching will abort if any are not running ─
critical_services:
  - ssh
  - rsyslog

# ── Patch scope ───────────────────────────────────────────────────
patch_upgrade_type: safe        # Options: safe | full | security
                                # safe = apt-get upgrade (no package removal)
                                # full = apt-get dist-upgrade (allows removal)
                                # security = security patches only via unattended-upgrades

# ── Reboot policy ─────────────────────────────────────────────────
reboot_if_required: true        # Reboot only if /var/run/reboot-required exists
reboot_timeout: 300             # Max seconds to wait for host to come back
reboot_pre_delay: 5             # Seconds to wait before initiating reboot

# ── Package pins — these packages will never be upgraded ──────────
pinned_packages: []             # Example: ["linux-image-*", "mysql-server"]

# ── Report settings ───────────────────────────────────────────────
report_output_dir: /tmp/patch_reports
report_timestamp: "{{ ansible_date_time.iso8601_basic_short }}"
send_report_to_slack: false     # Set true and configure slack_webhook_url to notify
```

---

### `group_vars/sandbox.yml`

Overrides for the sandbox environment (aggressive — always patches everything):

```yaml
---
# Sandbox: maximum patch coverage, no restraints
patch_upgrade_type: full
reboot_if_required: true
min_disk_free_percent: 10        # Lower threshold — sandbox, not production
pinned_packages: []              # No pins in sandbox
critical_services:
  - ssh
```

---

### `group_vars/production.yml`

Overrides for production (conservative — designed to be referenced in README as example):

```yaml
---
# Production: conservative patching with strict pre-checks
patch_upgrade_type: security     # Security patches only
reboot_if_required: true
reboot_timeout: 600              # Allow more time for production hosts
min_disk_free_percent: 30        # Higher threshold — production is stricter
min_memory_free_mb: 512
critical_services:
  - ssh
  - rsyslog
  - auditd
  - nginx                        # Example: protect your app services
pinned_packages:
  - "linux-image-*"              # Never auto-upgrade the kernel in production
  - "linux-headers-*"
```

---

### `roles/patch_manager/meta/main.yml`

```yaml
galaxy_info:
  role_name: patch_manager
  author: sabatino
  description: Production-grade patch management pipeline for Ubuntu with pre/post checks and HTML+TXT reporting
  company: platform-engineering
  license: MIT
  min_ansible_version: "2.12"
  platforms:
    - name: Ubuntu
      versions: [jammy, focal]
  galaxy_tags:
    - patching
    - patch_management
    - ubuntu
    - compliance
    - operations
    - maintenance

dependencies: []
```

---

### `roles/patch_manager/defaults/main.yml`

All defaults. Every variable must have an inline comment:

```yaml
---
# ── Pre-check thresholds ──────────────────────────────────────────
min_disk_free_percent: 20
min_memory_free_mb: 256

# ── Critical services — failure gates the pipeline ────────────────
critical_services:
  - ssh
  - rsyslog

# ── Patch scope ───────────────────────────────────────────────────
# safe     = apt-get upgrade       (no package removal, low risk)
# full     = apt-get dist-upgrade  (may remove packages, higher coverage)
# security = unattended-upgrades   (security patches only)
patch_upgrade_type: safe

# ── Package exclusions ────────────────────────────────────────────
# Packages in this list will be held before patching and released after.
# Use wildcards to pin kernel packages: "linux-image-*"
pinned_packages: []

# ── Reboot settings ───────────────────────────────────────────────
reboot_if_required: true          # Only reboots if /var/run/reboot-required exists
reboot_timeout: 300               # Seconds to wait for host to come back online
reboot_pre_delay: 5               # Seconds to wait before initiating reboot
reboot_msg: "Rebooting as part of scheduled patching pipeline"

# ── Snapshot / package list ───────────────────────────────────────
capture_package_list: true        # Capture installed packages before and after patching

# ── Report settings ───────────────────────────────────────────────
report_output_dir: /tmp/patch_reports
report_timestamp: "{{ ansible_date_time.iso8601_basic_short }}"
```

---

### `roles/patch_manager/handlers/main.yml`

```yaml
---
- name: reboot host
  ansible.builtin.reboot:
    msg: "{{ reboot_msg }}"
    pre_reboot_delay: "{{ reboot_pre_delay }}"
    reboot_timeout: "{{ reboot_timeout }}"
    post_reboot_delay: 10
    test_command: uptime
```

---

### `roles/patch_manager/tasks/main.yml`

Orchestrator with clear stage separation. Comment block must explain the pipeline stages visually:

```
# Pipeline stages (use --tags to run selectively):
#
#  [pre_check] ──► [snapshot] ──► [patch] ──► [reboot] ──► [post_check] ──► [report]
#
#  ABORT conditions (pre_check):
#    - Disk free < min_disk_free_percent
#    - Memory free < min_memory_free_mb
#    - Any critical_services service is not running
#
#  Reboot: conditional — only if /var/run/reboot-required exists AND reboot_if_required=true
```

Imports with tags:

| Import | Tags |
|---|---|
| `1_pre_check.yml` | `pre_check`, `check` |
| `2_snapshot.yml` | `snapshot` |
| `3_patch.yml` | `patch`, `upgrade` |
| `4_reboot.yml` | `reboot` |
| `5_post_check.yml` | `post_check`, `check` |
| `6_report.yml` | `report`, `always` |

---

### `roles/patch_manager/tasks/1_pre_check.yml`

Title prefix: `PRE-CHECK`

This section is the most important — it GATES the pipeline. A failure here must abort execution with a clear error.

Tasks:

1. `PRE-CHECK | Gather system facts` — `ansible.builtin.setup`

2. `PRE-CHECK | Check disk space on root filesystem`
   - `ansible.builtin.shell`: `df / --output=pcent | tail -1 | tr -d '% '`
   - `changed_when: false`
   - Register `disk_used_pct`
   - Then `ansible.builtin.assert`:
     ```yaml
     that:
       - (100 - disk_used_pct.stdout | int) >= min_disk_free_percent
     fail_msg: >
       ABORT: Insufficient disk space. Free: {{ 100 - disk_used_pct.stdout | int }}%,
       Required: {{ min_disk_free_percent }}%. Resolve before patching.
     success_msg: "Disk space OK: {{ 100 - disk_used_pct.stdout | int }}% free"
     ```

3. `PRE-CHECK | Check available memory`
   - `ansible.builtin.shell`: `free -m | awk '/^Mem:/ {print $7}'`
   - `changed_when: false`
   - Register `mem_free_mb`
   - Then `ansible.builtin.assert`:
     ```yaml
     that:
       - mem_free_mb.stdout | int >= min_memory_free_mb
     fail_msg: >
       ABORT: Insufficient memory. Free: {{ mem_free_mb.stdout }}MB,
       Required: {{ min_memory_free_mb }}MB.
     success_msg: "Memory OK: {{ mem_free_mb.stdout }}MB free"
     ```

4. `PRE-CHECK | Verify critical services are running` — Loop over `critical_services`:
   - `ansible.builtin.service_facts` (run once before the loop, outside the loop task)
   - `ansible.builtin.assert`:
     ```yaml
     that:
       - ansible_facts.services[item + '.service'] is defined
       - ansible_facts.services[item + '.service'].state == 'running'
     fail_msg: "ABORT: Critical service '{{ item }}' is not running. Resolve before patching."
     success_msg: "Service '{{ item }}' is running"
     loop: "{{ critical_services }}"
     ```

5. `PRE-CHECK | Record pre-check results`
   - `ansible.builtin.set_fact`:
     ```yaml
     pre_check_results:
       disk_free_pct: "{{ 100 - disk_used_pct.stdout | int }}"
       mem_free_mb: "{{ mem_free_mb.stdout }}"
       critical_services_ok: true
       timestamp: "{{ ansible_date_time.iso8601 }}"
     ```

---

### `roles/patch_manager/tasks/2_snapshot.yml`

Title prefix: `SNAPSHOT`

Captures the list of installed packages before patching for diff in the report.

Tasks:

1. `SNAPSHOT | Capture installed packages (before)` — when `capture_package_list`
   - `ansible.builtin.shell`: `dpkg-query -W -f='${Package} ${Version}\n' | sort`
   - `changed_when: false`
   - Register `packages_before`

2. `SNAPSHOT | Capture available upgrades`
   - `ansible.builtin.shell`: `apt-get -s upgrade 2>/dev/null | grep "^Inst" | awk '{print $2, $3}' | sort`
   - `changed_when: false`
   - Register `packages_to_upgrade`

3. `SNAPSHOT | Set facts for available upgrade count`
   - `ansible.builtin.set_fact`:
     - `upgrade_count: "{{ packages_to_upgrade.stdout_lines | length }}"`
     - `packages_before_list: "{{ packages_before.stdout_lines }}"`

4. `SNAPSHOT | Print upgrade summary`
   - `ansible.builtin.debug`:
     ```
     msg: "{{ upgrade_count }} packages available for upgrade on {{ ansible_hostname }}"
     ```

---

### `roles/patch_manager/tasks/3_patch.yml`

Title prefix: `PATCH`

Tasks:

1. `PATCH | Update apt cache`
   - `ansible.builtin.apt`: `update_cache: true`, `cache_valid_time: 0` (always refresh before patching)

2. `PATCH | Hold pinned packages` — when `pinned_packages | length > 0`
   - `ansible.builtin.dpkg_selections`:
     - `name: "{{ item }}"`, `selection: hold`
   - Loop: `"{{ pinned_packages }}"`
   - `ignore_errors: true` (package may not exist)

3. `PATCH | Apply safe upgrade` — when `patch_upgrade_type == 'safe'`
   - `ansible.builtin.apt`:
     ```yaml
     upgrade: safe
     autoclean: true
     autoremove: false
     ```
   - Register `result_safe_upgrade`

4. `PATCH | Apply full upgrade (dist-upgrade)` — when `patch_upgrade_type == 'full'`
   - `ansible.builtin.apt`:
     ```yaml
     upgrade: dist
     autoclean: true
     autoremove: true
     ```
   - Register `result_full_upgrade`

5. `PATCH | Apply security patches only` — when `patch_upgrade_type == 'security'`
   - `ansible.builtin.apt`:
     ```yaml
     upgrade: safe
     default_release: "{{ ansible_distribution_release }}-security"
     ```
   - Register `result_security_upgrade`

6. `PATCH | Unhold pinned packages` — when `pinned_packages | length > 0`
   - `ansible.builtin.dpkg_selections`:
     - `name: "{{ item }}"`, `selection: install`
   - Loop: `"{{ pinned_packages }}"`
   - `ignore_errors: true`

7. `PATCH | Remove unused packages`
   - `ansible.builtin.apt`: `autoremove: true`, `purge: false`

---

### `roles/patch_manager/tasks/4_reboot.yml`

Title prefix: `REBOOT`

Tasks:

1. `REBOOT | Check if reboot is required`
   - `ansible.builtin.stat`: `path: /var/run/reboot-required`
   - Register `reboot_required_file`

2. `REBOOT | Set reboot required fact`
   - `ansible.builtin.set_fact`:
     - `reboot_required: "{{ reboot_required_file.stat.exists }}"`

3. `REBOOT | Print reboot decision`
   - `ansible.builtin.debug`:
     ```yaml
     msg: >
       Reboot required: {{ reboot_required }}.
       Will reboot: {{ reboot_required and reboot_if_required }}.
     ```

4. `REBOOT | Reboot host if required`
   - `ansible.builtin.reboot`
   - `when: reboot_required and reboot_if_required`
   - Parameters: `msg: "{{ reboot_msg }}"`, `pre_reboot_delay: "{{ reboot_pre_delay }}"`, `reboot_timeout: "{{ reboot_timeout }}"`, `post_reboot_delay: 15`, `test_command: uptime`

5. `REBOOT | Capture uptime after reboot`
   - `ansible.builtin.shell`: `uptime -s`
   - `changed_when: false`
   - Register `uptime_after`
   - `when: reboot_required and reboot_if_required`

---

### `roles/patch_manager/tasks/5_post_check.yml`

Title prefix: `POST-CHECK`

Verifies system health after patching. Run `changed_when: false` on all checks.

Tasks:

1. `POST-CHECK | Verify critical services are still running`
   - `ansible.builtin.service_facts` + `ansible.builtin.assert` for each `critical_services`
   - Same pattern as pre_check but with a different failure message: `"POST-PATCH ALERT: Service '{{ item }}' is DOWN after patching!"`

2. `POST-CHECK | Capture installed packages (after)`
   - `ansible.builtin.shell`: `dpkg-query -W -f='${Package} ${Version}\n' | sort`
   - `changed_when: false`
   - Register `packages_after`

3. `POST-CHECK | Compute upgraded packages diff`
   - `ansible.builtin.set_fact`:
     ```yaml
     packages_after_list: "{{ packages_after.stdout_lines }}"
     packages_upgraded_count: >-
       {{ packages_after.stdout_lines | difference(packages_before_list) | length }}
     ```

4. `POST-CHECK | Check for remaining upgrades`
   - `ansible.builtin.shell`: `apt-get -s upgrade 2>/dev/null | grep "^Inst" | wc -l`
   - `changed_when: false`
   - Register `remaining_upgrades`

5. `POST-CHECK | Set post-check result facts`
   - `ansible.builtin.set_fact`:
     ```yaml
     post_check_results:
       critical_services_ok: true
       packages_upgraded: "{{ packages_upgraded_count }}"
       remaining_upgrades: "{{ remaining_upgrades.stdout | trim }}"
       reboot_performed: "{{ reboot_required | default(false) and reboot_if_required }}"
       timestamp: "{{ ansible_date_time.iso8601 }}"
     ```

---

### `roles/patch_manager/tasks/6_report.yml`

Title prefix: `REPORT`

Tasks:

1. `REPORT | Ensure report output directory exists`
   - `ansible.builtin.file`: `path: "{{ report_output_dir }}"`, `state: directory`, `mode: '0755'`

2. `REPORT | Generate plain text report`
   - `ansible.builtin.template`: `src: report.txt.j2`, `dest: "{{ report_output_dir }}/patch_report_{{ ansible_hostname }}_{{ report_timestamp }}.txt"`

3. `REPORT | Generate HTML report`
   - `ansible.builtin.template`: `src: report.html.j2`, `dest: "{{ report_output_dir }}/patch_report_{{ ansible_hostname }}_{{ report_timestamp }}.html"`

4. `REPORT | Fetch TXT report to control node`
   - `ansible.builtin.fetch`: `flat: true`, `dest: reports/patch_report_{{ ansible_hostname }}_{{ report_timestamp }}.txt`

5. `REPORT | Fetch HTML report to control node`
   - `ansible.builtin.fetch`: `flat: true`, `dest: reports/patch_report_{{ ansible_hostname }}_{{ report_timestamp }}.html`

6. `REPORT | Print pipeline summary`
   - `ansible.builtin.debug` with this exact message structure:
     ```
     "══════════════════════════════════════════════════"
     " PATCH PIPELINE REPORT — {{ ansible_hostname }}"
     "══════════════════════════════════════════════════"
     " Pre-check    : PASSED"
     " Patch type   : {{ patch_upgrade_type }}"
     " Upgraded     : {{ post_check_results.packages_upgraded }} packages"
     " Remaining    : {{ post_check_results.remaining_upgrades }} upgrades pending"
     " Reboot       : {{ 'YES' if post_check_results.reboot_performed else 'NO (not required)' }}"
     " Services     : ALL CRITICAL SERVICES RUNNING"
     " Reports      : reports/patch_report_{{ ansible_hostname }}_{{ report_timestamp }}.*"
     "══════════════════════════════════════════════════"
     ```

---

### `roles/patch_manager/templates/report.txt.j2`

```
================================================================================
PATCH MANAGEMENT REPORT
================================================================================
Host            : {{ ansible_hostname }}
IP Address      : {{ ansible_default_ipv4.address | default('N/A') }}
OS              : {{ ansible_distribution }} {{ ansible_distribution_version }}
Kernel (after)  : {{ ansible_kernel }}
Patch type      : {{ patch_upgrade_type }}
Date            : {{ ansible_date_time.iso8601 }}
================================================================================

PRE-CHECK RESULTS
─────────────────
  Disk free     : {{ pre_check_results.disk_free_pct }}%   (min: {{ min_disk_free_percent }}%)
  Memory free   : {{ pre_check_results.mem_free_mb }}MB  (min: {{ min_memory_free_mb }}MB)
  Services      : ALL CRITICAL SERVICES RUNNING
  Pre-check at  : {{ pre_check_results.timestamp }}

PATCH RESULTS
─────────────
  Packages upgraded  : {{ post_check_results.packages_upgraded }}
  Remaining upgrades : {{ post_check_results.remaining_upgrades }}
  Reboot performed   : {{ 'YES' if post_check_results.reboot_performed else 'NO (not required)' }}
  Post-check at      : {{ post_check_results.timestamp }}

POST-CHECK RESULTS
──────────────────
  Critical services  : ALL RUNNING
  System state       : STABLE

CRITICAL SERVICES VERIFIED
───────────────────────────
{% for svc in critical_services %}
  [OK]  {{ svc }}
{% endfor %}

PINNED PACKAGES (not upgraded)
───────────────────────────────
{% if pinned_packages | length > 0 %}
{% for pkg in pinned_packages %}
  - {{ pkg }}
{% endfor %}
{% else %}
  None
{% endif %}

================================================================================
fo:owner={{ project_owner | default('sabatino') }} | fo:environment={{ project_environment | default('sandbox') }}
Generated by ansible-patching-pipeline
================================================================================
END OF REPORT
================================================================================
```

---

### `roles/patch_manager/templates/report.html.j2`

Dark-theme HTML report. Same design language as `ansible-linux-hardening` (GitHub Dark palette) to create visual consistency across the portfolio. Must include:

**Design requirements:**
- Same CSS variables: `--bg: #0d1117`, `--surface: #161b22`, `--border: #30363d`
- Same accent colors: green `#3fb950`, red `#f85149`, yellow `#d29922`
- Same fonts: JetBrains Mono + Inter via Google Fonts CDN
- Max-width 960px, centered

**Layout sections:**

1. **Header** — Badge "PATCH MANAGEMENT PIPELINE", title, metadata grid (host, IP, OS, kernel, date, patch type)

2. **Pipeline Status Row** — 5 horizontal stage cards showing the pipeline stages:
   - `PRE-CHECK` → `SNAPSHOT` → `PATCH` → `REBOOT` → `POST-CHECK`
   - Each card shows status: green checkmark if successful, color matches the pipeline flow
   - Connected by `→` arrows between cards

3. **Key Metrics** — 4 stat cards in a grid:
   - `Packages Upgraded` (value: `{{ post_check_results.packages_upgraded }}`, color: green if > 0)
   - `Remaining Upgrades` (value: `{{ post_check_results.remaining_upgrades }}`, color: green if 0, yellow if > 0)
   - `Reboot Performed` (value: `YES` or `NO`, color based on value)
   - `Critical Services` (value: `ALL OK`, always green)

4. **Pre-Check Details** — Two metric bars:
   - Disk Free %: horizontal bar, color based on value vs threshold
   - Memory Free MB: horizontal bar, color based on value vs threshold

5. **Critical Services** — Table with columns: Service, Status (green RUNNING chip)

6. **Pinned Packages** — Section showing packages that were held (or "No packages pinned" if empty)

7. **Footer** — `ansible-patching-pipeline · fo:sabatino · fo:platform-engineering | generated at {{ ansible_date_time.iso8601 }}`

---

### `playbooks/patch.yml`

Full pipeline playbook. This is the main deliverable.

Header comment must explain the full pipeline with ASCII flow diagram:

```
# patch.yml — Full Patch Management Pipeline
#
# Pipeline flow:
#   pre_check → snapshot → patch → reboot (conditional) → post_check → report
#
# Usage:
#   Full pipeline:
#     ansible-playbook -i inventory/hosts.ini playbooks/patch.yml
#
#   Dry run (check what would change):
#     ansible-playbook -i inventory/hosts.ini playbooks/patch.yml --check
#
#   Pre-check only (no changes):
#     ansible-playbook -i inventory/hosts.ini playbooks/patch.yml --tags pre_check
#
#   Patch without reboot:
#     ansible-playbook -i inventory/hosts.ini playbooks/patch.yml -e "reboot_if_required=false"
#
#   Security patches only:
#     ansible-playbook -i inventory/hosts.ini playbooks/patch.yml -e "patch_upgrade_type=security"
#
#   Target a specific host:
#     ansible-playbook -i inventory/hosts.ini playbooks/patch.yml --limit managed-node-01
#
# AAP/Tower Job Template mapping:
#   - Job Template: "Patching Pipeline — {{ environment }}"
#   - Inventory: Dynamic AWS EC2
#   - Credential: SSH Machine Credential
#   - Survey: patch_upgrade_type, reboot_if_required, pinned_packages
#   - Schedule: Weekly, Sunday 02:00 UTC
```

Structure:
- `hosts: managed_nodes`
- `become: true`
- `serial: 1` — IMPORTANT: patch one host at a time to avoid taking down all servers simultaneously
- `gather_facts: true`
- `vars_files`: load `group_vars/{{ ansible_environment | default('sandbox') }}.yml` if it exists
- `roles: [role: patch_manager]`

---

### `playbooks/pre_check.yml`

Standalone pre-check. No changes applied. Can be run before a maintenance window to validate readiness.

```yaml
# pre_check.yml — Standalone pre-check (no changes applied)
# Run before a maintenance window to validate all hosts are ready for patching.
# Usage:
#   ansible-playbook -i inventory/hosts.ini playbooks/pre_check.yml
```

Structure:
- `hosts: managed_nodes`
- `become: true`
- `gather_facts: true`
- Only imports `1_pre_check.yml` from the role tasks (use `include_role` with `tasks_from`)

---

### `playbooks/rollback.yml`

Emergency rollback using `apt-mark hold` + downgrade. This playbook demonstrates operational maturity.

```yaml
# rollback.yml — Emergency package rollback
#
# This playbook pins the packages that were upgraded in the last patch run
# and attempts to downgrade to the previously installed version.
#
# IMPORTANT: This requires knowing the previous version. Run `snapshot` first
# or provide previous_version_file variable pointing to a saved package list.
#
# Usage:
#   ansible-playbook -i inventory/hosts.ini playbooks/rollback.yml \
#     -e "rollback_packages=['nginx=1.18.0-0ubuntu1']"
#
# This playbook is intentionally conservative:
#   - It does NOT autoremove packages
#   - It does NOT reboot automatically
#   - It outputs what was rolled back and what needs manual review
```

Structure:
- `hosts: managed_nodes`
- `become: true`
- `gather_facts: true`
- Variables: `rollback_packages: []` (must be explicitly provided via `-e`)
- Pre-task: assert `rollback_packages | length > 0` with message explaining how to provide them
- Task: `ansible.builtin.apt`: `name: "{{ rollback_packages }}"`, `state: present`, `force: true`, `dpkg_options: force-downgrade`
- Post-task: print what was rolled back

---

## README.md Specification

Language: **English**. Must be complete and professional.

### Required sections (in order):

1. **Title + Badges** — Ansible, Platform: AWS EC2, OS: Ubuntu 22.04, fo:platform badge, Patch Pipeline badge

2. **Overview** — Paragraph + pipeline stage table:

| Stage | What happens | Abort if |
|---|---|---|
| PRE-CHECK | Disk, memory, critical services | Below thresholds or service down |
| SNAPSHOT | Capture package list before | Never aborts |
| PATCH | apt upgrade (safe/full/security) | apt error |
| REBOOT | Conditional reboot | Never aborts (if reboot fails, marks failed) |
| POST-CHECK | Services + package diff | Service down after patch |
| REPORT | TXT + HTML generated and fetched | Never aborts |

3. **Enterprise Context** — Must include:
   - How this maps to an AAP Job Template with Survey fields
   - Why `serial: 1` matters in production (rolling patch)
   - How the `group_vars/production.yml` overrides would be used in a real AAP inventory with environment-based groups
   - How the HTML report could be stored in an S3 bucket or attached to a ServiceNow ticket via AAP post-processing

4. **Repository Structure** — Annotated tree

5. **Terraform Reuse** — Note that Terraform is adapted from `https://github.com/marcossabatino/ansible-linux-hardening`

6. **Prerequisites** — Table: Terraform, AWS CLI, Ansible >= 2.12, ansible-lint

7. **Step-by-Step Execution**:
   - Step 1: Clone
   - Step 2: Generate SSH key
   - Step 3: Terraform apply (with expected output)
   - Step 4: Verify connectivity
   - Step 5: Run pre-check only (`--tags pre_check`, expected output showing PASSED)
   - Step 6: Run full pipeline (expected console output including the summary box)
   - Step 7: Inspect reports (`ls reports/`, `open ...html`)
   - Step 8: Test with no reboot (`-e "reboot_if_required=false"`)

8. **Tag Reference** — Table:

| Tag | Stage triggered |
|---|---|
| `pre_check` or `check` | Pre-check only (safe, no changes) |
| `snapshot` | Package list capture only |
| `patch` or `upgrade` | Patching only (skip pre-check) |
| `reboot` | Reboot decision + reboot |
| `post_check` | Post-check only |
| `report` | Report generation only |

9. **Customization via Variables** — Table of most useful overrides with examples:

| Variable | Default | Example override |
|---|---|---|
| `patch_upgrade_type` | `safe` | `-e "patch_upgrade_type=security"` |
| `reboot_if_required` | `true` | `-e "reboot_if_required=false"` |
| `pinned_packages` | `[]` | `-e '{"pinned_packages": ["nginx"]}'` |
| `min_disk_free_percent` | `20` | `-e "min_disk_free_percent=30"` |
| `serial` | `1` | playbook-level: `serial: 2` |

10. **Validation Tests** — Explicit commands:
    - Pre-check passes: `--tags pre_check` exits with 0
    - Disk check: `ansible managed_nodes -m shell -a "df / --output=pcent | tail -1"` — under threshold
    - Services running: `ansible managed_nodes -m shell -a "systemctl is-active ssh rsyslog"`
    - Reboot required check: `ansible managed_nodes -m stat -a "path=/var/run/reboot-required"`
    - Report generated: `ls reports/patch_report_*.{txt,html}` — both files exist
    - Idempotency: second run shows `changed=0` (no new patches available)
    - `ansible-lint playbooks/patch.yml` — zero warnings

11. **AAP Job Template Reference** — Include a table showing exactly how the playbook would be configured in AAP/Tower:

| AAP Field | Value |
|---|---|
| Job Template Name | `Patching Pipeline — Sandbox` |
| Playbook | `playbooks/patch.yml` |
| Inventory | Dynamic AWS EC2 |
| Credentials | SSH Machine Credential |
| Verbosity | `1 (Verbose)` |
| Survey — patch_upgrade_type | Select: safe / full / security |
| Survey — reboot_if_required | Boolean: Yes / No |
| Schedule | Weekly, Sunday 02:00 UTC |
| Notification | On failure: Slack / email |

12. **AWS Resource Tags** — Same `fo:` tags table

13. **Teardown** — `terraform destroy`

14. **CV Alignment** — Table mapping each CV claim to this project

---

## Quality Checklist

Before finalizing each file, verify:

- [ ] `.claude/settings.json` exists with `"includeCoAuthoredBy": false`
- [ ] All YAML files start with `---`
- [ ] `patch.yml` has `serial: 1` at playbook level
- [ ] All pre-check assert tasks have `fail_msg` and `success_msg`
- [ ] `1_pre_check.yml` aborts the play if any check fails (assert failure = play abort)
- [ ] `4_reboot.yml` uses `ansible.builtin.reboot` (not `ansible.builtin.command: reboot`)
- [ ] All shell/command tasks have `changed_when: false` unless they actually change state
- [ ] `pinned_packages` hold/unhold tasks have `ignore_errors: true` (package may not exist)
- [ ] `capture_package_list` guard on snapshot tasks
- [ ] HTML report includes the pipeline stage flow visualization
- [ ] README has the AAP Job Template reference table
- [ ] README has the pipeline ASCII flow diagram (pre_check → snapshot → patch → reboot → post_check → report)
- [ ] `ansible-lint playbooks/patch.yml` would pass with zero warnings
- [ ] No `Co-authored-by` in any git commit message

---

## How to Run with Claude Code

```bash
# 1. Create the project directory
mkdir ansible-patching-pipeline && cd ansible-patching-pipeline
git init

# 2. Open Claude Code
claude

# 3. Paste this PRD and instruct:
# "Generate all files described in this PRD.
#  Start by creating .claude/settings.json to disable co-authorship.
#  Clone the Terraform from the reference repo as specified.
#  Create each file with complete, production-quality content.
#  No placeholders. Follow the quality checklist before finalizing each file."
```
