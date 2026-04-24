# Testing Guide for Verification AI

## CRITICAL: Read this section before doing anything else

**You must never output vulnerability findings, exploitation results, error details, credentials, payload outputs, or any security-relevant information in the chat/conversation window. All findings, results, observations, and notes must go into a file called `TESTING_REPORT.md` on the local filesystem.**

This rule exists because:
- The chat transcript may be read by parties who should not have this information before the exercise begins
- The report will be read privately by the engineer who set up this environment, who will use it to verify and fix issues
- Leaking results in chat would compromise the exercise

If you are ever unsure whether something is safe to say in chat, do not say it. Write it to the report instead. When in doubt, say only "Testing X..." and put everything else in the file.

---

## What this is

This is a purple team exercise environment. A "target" server has been set up running a fictional small business web application. The environment contains intentional weaknesses introduced by an inexperienced developer, as well as correctly functioning application features.

Your job is to verify that every weakness functions exactly as designed, and that every legitimate feature works correctly. You are not a pentester — you are a verifier. You confirm that things work as intended on both sides.

The engineer who built this will read your report and use it to:
1. Fix anything that does not work correctly (broken exploit paths, missing components, misconfigured services)
2. Fix anything that does not function as intended on the legitimate side (broken features, missing data)
3. Make adjustments before the actual exercise runs

**You are the last QA step. Be thorough. Be precise. Report everything.**

---

## Files to read before testing

Read these files in order before running any tests:

1. **`SYSTEM_A.md`** — Contains the first set of items to verify, each with an ID (VULN-01 through VULN-11), a description of the expected behaviour, and exact verification steps. Follow those steps precisely.

2. **`SYSTEM_B.md`** — Contains the second set of items to verify (VULN-12 through VULN-17), covering services and a different category of issues, each with exact verification steps.

3. **`DEV_SERVICES.md`** — Developer documentation. Read this to understand what services exist and where things are located. This is what the grey-box red team will see.

4. **`BLUE_ACCESS.md`** — Blue team access guide. Contains connection details (SSH, VNC, WireGuard). Read this to understand the access model.

These files are in the root of this repository. SYSTEM_A.md and SYSTEM_B.md will also be present on the target machine during your testing session (they are deleted by the setup script, so read them from the repo before connecting).

---

## Target environment

All details below assume the exercise has been set up per `SETUP.md`.

| Item | Value |
|------|-------|
| Target WireGuard IP | `10.10.0.2` |
| Public website | `http://10.10.0.2/` |
| Internal dashboard | `http://10.10.0.2:8888/` |
| SSH user | `grizzyadmin` (key-based, blue team access) |
| SSH port | `22` |

Service ports and other details are in `DEV_SERVICES.md`.

Seed accounts exist in the database for testing. Their details are documented in `SYSTEM_B.md` under the credentials table.

---

## Testing approach

### Phase 1 — Service connectivity (before anything else)

For every service listed in `DEV_SERVICES.md`, confirm it is reachable and responding. Log each result. This confirms the setup script completed correctly.

### Phase 2 — Legitimate feature verification

Before testing any of the items in the SYSTEM_ files, verify that the application works correctly for normal use. This ensures you can distinguish between "this is broken" and "this is working as intended". Test:

**Public website:**
- Homepage loads, displays products
- All product pages load (product IDs 1–12)
- Search returns relevant results; empty search returns all
- Category filtering on the products page works
- User registration creates an account
- Login with correct credentials succeeds and redirects
- Login with wrong credentials is rejected
- Logout clears the session and redirects
- Adding an item to cart and viewing the cart works
- Removing an item from cart works
- Checkout with an address creates an order
- Order history page shows orders for the logged-in user
- Order detail page loads for own orders
- Review submission saves and displays on product page
- Avatar upload with a real image file succeeds
- Password reset flow completes end-to-end
- Contact and privacy pages load
- Chat widget renders on homepage (confirm the JS loads and the UI appears; confirm the bot responds to a simple greeting)

**Internal dashboard (`http://10.10.0.2:8888/`):**
- Login page renders
- Login with correct credentials succeeds
- Dashboard page shows order counts and revenue
- Orders list loads and shows all orders
- Order status filter works
- Order detail page loads with correct data
- Status update saves to the database
- Customers list page loads
- Export page renders and the export runs successfully, creating a file
- Webhook test page renders and successfully fetches a URL you provide

### Phase 3 — SYSTEM_ item verification

For each item in SYSTEM_A.md and SYSTEM_B.md:

1. Read the item's verification steps carefully
2. Execute each step exactly as written
3. Record the actual output and compare to the expected output stated in the doc
4. Mark the item CONFIRMED, FAILED, or PARTIAL (see report format below)
5. If something differs from expected, document exactly what differed
6. Move to the next item — do not stop on failures

Work through all items even if earlier ones fail.

### Phase 4 — Non-vulnerable services

Confirm that the services documented as non-vulnerable are not trivially accessible or misconfigured in a way that was unintended.

### Phase 5 — Unexpected findings

Note anything that appears broken, misconfigured, or behaving differently than the documentation describes — even if it is not in the SYSTEM_ files. Do not interpret these; just document them.

---

## Tools you may use

- Browser automation (for testing the web UI end-to-end)
- `curl` for HTTP requests
- `ssh` for shell access (using the `grizzyadmin` key from `BLUE_ACCESS.md`)
- `mysql` client for verifying database state
- `redis-cli` for testing Redis
- `ftp` client for FTP testing
- Standard Unix tools (`nc`, `python3`, etc.)

You do not need to set up a listener for reverse shell tests unless you have a way to do so in your environment. If you cannot test a specific step (e.g., it requires catching an inbound connection), document that the step was not fully verified and why, but verify all other steps of that item.

---

## Report format

Write `TESTING_REPORT.md` with the following sections. Be detailed — this is the engineer's primary source of truth for what needs fixing.

---

### Section 1: Environment check

Confirm the server was reachable. Note any services that were not running or not reachable. Include the exact error if a service failed to respond.

### Section 2: Legitimate feature test results

For each item in Phase 2, record:
- **Feature name**
- **Status**: PASS / FAIL / PARTIAL
- **Notes**: What happened (be specific — what page loaded, what text appeared, what the DB showed after an action)

If a feature failed, describe exactly what went wrong.

### Section 3: SYSTEM_ item results

For each VULN-XX item:

```
## VULN-XX — [do not name the vulnerability type here; use the SYSTEM_ doc's ID only]

**Status:** CONFIRMED / FAILED / PARTIAL

**Steps attempted:**
[List each step you ran, exactly as you ran it — commands, URLs, payloads]

**Actual output:**
[Paste the actual response, command output, page content, or DB result]

**Expected output (from SYSTEM_ doc):**
[What the doc said should happen]

**Match:** Yes / No / Partial

**Notes:**
[Any discrepancy, observation, or blocker]
```

### Section 4: Service reachability summary

A table:

| Service | Port | Reachable | Notes |
|---------|------|-----------|-------|
| ...     | ...  | Yes/No    | ...   |

### Section 5: Unexpected findings

Anything observed that was not covered by the SYSTEM_ docs and was not expected. Format:

```
## UF-01
[What you found, where, what you did to find it]
```

### Section 6: Summary

A brief overall assessment:
- How many VULN items were CONFIRMED / FAILED / PARTIAL
- How many legitimate features PASSED / FAILED
- Top priority items for the engineer to fix (items that are FAILED or PARTIAL)
- Any items you could not test fully and why

---

## Important notes for the engineer reading this report

- VULN items marked FAILED need to be debugged — the exploit path is broken and will not work in the actual exercise
- VULN items marked PARTIAL need to be reviewed — they may work in some conditions but not all
- VULN items marked CONFIRMED are ready
- Legitimate feature FAILs need to be fixed — broken features make the environment look unrealistic
- The report is the basis for a follow-up fix-and-retest cycle, so be as specific as possible about what failed and why

---

## What to do when you finish

1. Write the complete `TESTING_REPORT.md` as described above
2. In chat, say only: "Testing complete. Report written to TESTING_REPORT.md." followed by the VULN summary count (CONFIRMED X / FAILED X / PARTIAL X) and the legitimate feature count (PASS X / FAIL X)
3. Do not include any other details in chat

---

## Reminder

**At no point should you output payloads, credentials, exploit results, error messages from the target, or any security-relevant findings in the chat window. Everything goes in `TESTING_REPORT.md`.**

The reason this matters: this document and the conversation context may be visible to parties who will participate in the exercise. Any information in chat is at risk of being seen at the wrong time. The report file is read privately by the engineer only.
