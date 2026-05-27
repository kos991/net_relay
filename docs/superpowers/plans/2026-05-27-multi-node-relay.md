# Multi-Node Relay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add create and join multi-node relay group support to the installer and OVA first-boot flow.

**Architecture:** Keep relay nodes independent. Extend `setup-relay.sh` with a deployment-mode prompt, stricter secret handling for join mode, `.env` metadata, and clearer Management config output. Update the OVA first-boot banner only; it already delegates setup to the installer.

**Tech Stack:** Bash, Docker Compose, GitHub Actions script checks.

---

## File Structure

- Modify `setup-relay.sh`: add deployment mode helpers, write relay group metadata to `.env`, enforce join-mode secret input, and print mode-specific Management config guidance.
- Modify `ova/files/net-relay-firstboot`: update the first-boot banner to mention creating or joining a multi-node relay group.
- Modify `tests/ova-scripts-check.sh`: add static checks for stable function names, variables, validation branches, and first-boot messaging.

---

### Task 1: Add Installer Mode Selection

**Files:**
- Modify: `setup-relay.sh`
- Modify: `tests/ova-scripts-check.sh`

- [ ] **Step 1: Add failing static checks**

Add these checks after the existing secret-related setup check in `tests/ova-scripts-check.sh`:

```bash
grep -q "select_relay_group_mode" "$SETUP"
grep -q "RELAY_GROUP_MODE" "$SETUP"
grep -q "create" "$SETUP"
grep -q "join" "$SETUP"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ova-scripts-check.sh
```

Expected: FAIL because `setup-relay.sh` does not yet contain `select_relay_group_mode`.

- [ ] **Step 3: Add mode selection helpers**

In `setup-relay.sh`, add this function after `prompt_default()`:

```bash
select_relay_group_mode() {
  local value=""

  while true; do
    cat >&2 <<'EOF'
部署模式：
  1. 创建新的 Relay 节点组
  2. 加入已有 Relay 节点组
EOF
    value="$(read_input '请选择部署模式 [1]: ')"
    if [[ -z "$value" || "$value" == "1" ]]; then
      printf 'create'
      return 0
    fi
    if [[ "$value" == "2" ]]; then
      printf 'join'
      return 0
    fi
    warn "请输入 1 或 2。"
  done
}
```

Add this assignment immediately after `ensure_docker`:

```bash
RELAY_GROUP_MODE="$(select_relay_group_mode)"
```

- [ ] **Step 4: Run the test to verify it passes this task**

Run:

```bash
bash tests/ova-scripts-check.sh
```

Expected: PASS for the new prompt checks. Other unrelated checks should keep their current behavior.

- [ ] **Step 5: Commit**

Run:

```bash
git add setup-relay.sh tests/ova-scripts-check.sh
git commit -m "feat: add relay node group mode prompt"
```

---

### Task 2: Enforce Join-Mode Secret Handling

**Files:**
- Modify: `setup-relay.sh`
- Modify: `tests/ova-scripts-check.sh`

- [ ] **Step 1: Add failing static checks**

Add these checks after the new `RELAY_GROUP_MODE` checks in `tests/ova-scripts-check.sh`:

```bash
grep -q "read_relay_auth_secret" "$SETUP"
grep -q 'if [[ "$RELAY_GROUP_MODE" == "join" && -z "$RELAY_AUTH_SECRET" ]]' "$SETUP"
grep -q "must provide an existing relay auth secret" "$SETUP"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ova-scripts-check.sh
```

Expected: FAIL because join-mode secret validation is not implemented.

- [ ] **Step 3: Add the secret helper**

In `setup-relay.sh`, add this function after `select_relay_group_mode()`:

```bash
read_relay_auth_secret() {
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    read_secret '已有节点组 secret（必填）：'
  else
    read_secret '认证密钥 secret（可留空自动生成；多节点请保存并复用）：'
  fi
}
```

Replace the existing direct `RELAY_AUTH_SECRET="$(read_secret ...)"` assignment near the bottom of `setup-relay.sh` with:

```bash
RELAY_AUTH_SECRET="$(read_relay_auth_secret)"
```

Replace the existing empty-secret block with:

```bash
if [[ "$RELAY_GROUP_MODE" == "join" && -z "$RELAY_AUTH_SECRET" ]]; then
  fail "must provide an existing relay auth secret when joining a relay node group."
fi

if [[ -z "$RELAY_AUTH_SECRET" ]]; then
  RELAY_AUTH_SECRET="$(generate_secret)"
  log "已自动生成认证密钥。请保存这个 secret，后续 Relay 节点和 Management 必须使用同一个值。"
fi
```

- [ ] **Step 4: Run syntax and static tests**

Run:

```bash
bash -n setup-relay.sh
bash tests/ova-scripts-check.sh
```

Expected: both commands PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add setup-relay.sh tests/ova-scripts-check.sh
git commit -m "feat: require existing secret when joining relay group"
```

---

### Task 3: Store Relay Group Metadata

**Files:**
- Modify: `setup-relay.sh`
- Modify: `tests/ova-scripts-check.sh`

- [ ] **Step 1: Add failing static checks**

Add these checks after the join-mode validation checks in `tests/ova-scripts-check.sh`:

```bash
grep -q "RELAY_NODE_NAME=" "$SETUP"
grep -q "RELAY_NODE_NAME=\${RELAY_NODE_NAME}" "$SETUP"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ova-scripts-check.sh
```

Expected: FAIL because `RELAY_NODE_NAME` is not stored yet.

- [ ] **Step 3: Add relay node name metadata**

In `setup-relay.sh`, add this assignment immediately after the `RELAY_DOMAIN="$(prompt_nonempty ...)"` line:

```bash
RELAY_NODE_NAME="${RELAY_DOMAIN}"
```

In `write_env_files()`, add these two lines after `RELAY_DOMAIN=${RELAY_DOMAIN}`:

```bash
RELAY_GROUP_MODE=${RELAY_GROUP_MODE}
RELAY_NODE_NAME=${RELAY_NODE_NAME}
```

- [ ] **Step 4: Run syntax and static tests**

Run:

```bash
bash -n setup-relay.sh
bash tests/ova-scripts-check.sh
```

Expected: both commands PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add setup-relay.sh tests/ova-scripts-check.sh
git commit -m "feat: store relay node group metadata"
```

---

### Task 4: Print Multi-Node Management Guidance

**Files:**
- Modify: `setup-relay.sh`
- Modify: `tests/ova-scripts-check.sh`

- [ ] **Step 1: Add failing static checks**

Add these checks near the existing summary checks in `tests/ova-scripts-check.sh`:

```bash
grep -q "mode_label" "$SETUP"
grep -q "relays.addresses" "$SETUP"
grep -q "same secret" "$SETUP"
grep -q "RELAY_NODE_NAME" "$SETUP"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ova-scripts-check.sh
```

Expected: FAIL because the new summary structure does not exist yet.

- [ ] **Step 3: Replace `print_summary()`**

Replace the existing `print_summary()` function in `setup-relay.sh` with:

```bash
print_summary() {
  local mode_label="创建新的 Relay 节点组"
  if [[ "$RELAY_GROUP_MODE" == "join" ]]; then
    mode_label="加入已有 Relay 节点组"
  fi

  cat <<EOF

==================== 安装完成 ====================
当前节点组模式：${mode_label}
当前节点名称：${RELAY_NODE_NAME}
Relay 地址：rels://${RELAY_DOMAIN}:${RELAY_PORT}
STUN 地址：stun:${RELAY_DOMAIN}:${STUN_PORT}
认证密钥：${RELAY_AUTH_SECRET}

把下面配置合并到 NetBird Management 的 config.yaml：
server:
  relays:
    addresses:
      - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"
    secret: "${RELAY_AUTH_SECRET}"
  stuns:
    - uri: "stun:${RELAY_DOMAIN}:${STUN_PORT}"
      proto: udp

如果这是追加节点，请把下面地址追加到现有 NetBird Management config.yaml：
relays.addresses:
  - "rels://${RELAY_DOMAIN}:${RELAY_PORT}"

stuns:
  - uri: "stun:${RELAY_DOMAIN}:${STUN_PORT}"
    proto: udp

All Relay nodes and Management must use the same secret.
常用命令：
  cd ${SCRIPT_DIR}
  ${COMPOSE_CMD[*]} logs -f caddy sync-relay-certs relay
  ${COMPOSE_CMD[*]} restart relay
EOF
}
```

- [ ] **Step 4: Run syntax and static tests**

Run:

```bash
bash -n setup-relay.sh
bash tests/ova-scripts-check.sh
```

Expected: both commands PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add setup-relay.sh tests/ova-scripts-check.sh
git commit -m "feat: print multi-node management config guidance"
```

---

### Task 5: Update OVA First-Boot Messaging

**Files:**
- Modify: `ova/files/net-relay-firstboot`
- Modify: `tests/ova-scripts-check.sh`

- [ ] **Step 1: Add failing static check**

Add this check after the existing first-boot completion check in `tests/ova-scripts-check.sh`:

```bash
grep -q "multi-node relay group" "$FIRSTBOOT"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ova-scripts-check.sh
```

Expected: FAIL because the first-boot banner does not mention multi-node support.

- [ ] **Step 3: Update the first-boot banner**

In `ova/files/net-relay-firstboot`, add this line inside the heredoc banner after the existing usage text:

```text
- Supports creating a new multi-node relay group or joining an existing group. Reuse the same secret on every node.
```

- [ ] **Step 4: Run syntax and static tests**

Run:

```bash
bash -n ova/files/net-relay-firstboot
bash tests/ova-scripts-check.sh
```

Expected: both commands PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add ova/files/net-relay-firstboot tests/ova-scripts-check.sh
git commit -m "feat: mention multi-node setup in OVA first boot"
```

---

### Task 6: Final Verification

**Files:**
- Verify only.

- [ ] **Step 1: Run syntax checks**

Run:

```bash
bash -n setup-relay.sh
bash -n ova/files/net-relay-firstboot
bash -n tests/ova-scripts-check.sh
```

Expected: all commands exit 0.

- [ ] **Step 2: Run repository script checks**

Run:

```bash
bash tests/ova-scripts-check.sh
```

Expected: PASS with exit 0.

- [ ] **Step 3: Inspect final diff**

Run:

```bash
git diff -- setup-relay.sh ova/files/net-relay-firstboot tests/ova-scripts-check.sh
```

Expected: diff only contains multi-node mode prompt, secret validation, `.env` metadata, summary output, first-boot messaging, and test checks.

- [ ] **Step 4: Commit any remaining verification-only adjustments**

If Task 6 required small fixes, commit them:

```bash
git add setup-relay.sh ova/files/net-relay-firstboot tests/ova-scripts-check.sh
git commit -m "test: verify multi-node relay installer flow"
```

If there are no remaining changes, do not create an empty commit.

