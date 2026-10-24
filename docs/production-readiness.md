# Production readiness review

This is a code-level checklist based on the current client queries. The repository does not include the authoritative Supabase schema or migrations, so policy names, columns, and SQL must be checked against the actual project before applying anything. No policy changes are made here.

## Prioritized findings

### P0 — complete before a public release

- **Supabase RLS is unverified.** Enable and review RLS on every exposed table. Verify that `users` queries disclose only intended profile fields; `chats` and `messages` are limited to participants; `friend_requests` reads and writes are limited to the sender/recipient; `calls` are limited to caller/receiver; `groups`, `group_members`, and `group_messages` require membership and role checks; `stories` honor the intended audience and expiry; `typing_statuses` are limited to chat members; and `user_devices` can only be managed by the owning account. Test both allowed and denied cases with separate real accounts.
- **Storage uses public URL helpers.** The client uses `getPublicUrl` for `avatars`, `chat_images`, and `stories`. Decide which media is truly public. For private media, use private buckets and signed URLs, and add object-level RLS that binds paths to authenticated users and conversation/group membership. Restrict MIME types, size, and upload paths.
- **Signaling deployment requires authenticated access and TLS.** `server.js` now validates a Supabase access token and checks call membership through the authenticated user's PostgREST permissions before joining. Deploy behind TLS as `wss://`; do not expose plain WebSocket traffic publicly. Add rate limiting, connection quotas, monitoring, and availability controls at the proxy/hosting layer.
- **Call-state mutations depend on database policy.** Client-side checks are usability checks. RLS must enforce who may create, answer, reject, and end calls, and validate permitted state transitions. The signaling service must not be considered a replacement for these policies.
- **Secrets and runtime configuration.** Flutter now requires project URL and public anon/publishable client key through `--dart-define`; do not pass a service-role key to the app. The signaling service needs the project URL and public client key as process environment variables. Keep production values in the deployment secret/configuration manager.

### P1 — resolve before broad rollout

- Review notification registration and revoke behavior; ensure device tokens are only readable by their owner and are removed on sign-out/account deletion.
- Verify retention, account deletion, abuse reporting/blocking, privacy disclosures, and media deletion behavior with product/legal requirements.
- Load-test chat list/history and realtime subscriptions against realistic data. Confirm pagination and bounded history before large deployments.
- Add structured, redacted client/server diagnostics and operational monitoring. Never log access tokens, message bodies, or full signaling payloads.
- Review TURN configuration. STUN-only connectivity will fail for some NAT/firewall combinations; production calling generally needs an appropriately secured TURN service and credential lifecycle.
- Confirm app signing, store privacy declarations, crash reporting, backups, and recovery procedures.

## Manual Supabase review

Before launch, inspect the live schema and policies in a staging project and record the review. At minimum test the following using authenticated users A, B, and unrelated user C:

1. A and B can read and write only their own one-to-one conversation; C cannot select, insert, update, or delete its messages.
2. Group members can access only groups they belong to; non-members cannot read history or add messages/members. Verify admin-only actions separately.
3. Call participants alone can read and transition their call rows; unrelated users cannot observe or mutate them. Reject invalid status transitions.
4. Friend requests can only be created by the authenticated sender and accepted/declined by the recipient.
5. Typing and presence rows cannot be used to enumerate unrelated users.
6. Storage reads and writes match the chosen public/private media policy, including attempts to access another account's path.
7. Anonymous access to all private tables and buckets is denied. Verify through the public client key, not an elevated SQL/service-role context.

Do not copy generic SQL policies without reconciling them with the actual schema, triggers, and existing product behavior.

## Real-device smoke checklist

- Install a release-like build on at least one physical Android and one physical iOS device.
- Sign up, confirm email if enabled, sign in/out, request a password reset, and reopen after force-stop.
- Verify dark and light theme, large text, screen reader labels, keyboard resize, and narrow/large layouts.
- Send/receive text and image messages on Wi-Fi and mobile data; test offline send failure, reconnect, history order, and unread behavior.
- Test audio/video call between two accounts on separate networks, including camera/mic denial, incoming call, decline, interruption, Bluetooth/audio routing, app backgrounding, and network loss.
- Verify stories, contacts, groups, avatars, and notifications only expose data to intended audiences.
- Capture logs with secrets and personal message content redacted.

## Build and release gate

- [ ] Supabase schema and RLS reviewed in staging, with denial cases tested.
- [ ] Storage privacy, upload limits, and retention approved.
- [ ] Signaling hosted behind WSS; token and membership checks verified.
- [ ] TURN strategy and network behavior verified on real devices.
- [ ] `dart format`, `flutter analyze`, and `flutter test` reviewed; analyzer output contains no unexplained warnings/errors.
- [ ] Android/iOS release builds completed with production signing and privacy declarations.
- [ ] Rollback, monitoring, incident response, and account/data recovery documented.
