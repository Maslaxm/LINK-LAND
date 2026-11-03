# LINK-LAND

**Guri iyo Dhul iibka & kirada** — a production-ready real-estate marketplace for Somalia.

LINK-LAND connects buyers, renters, agents and sellers of houses and land through a public,
Somali-first website and a private admin dashboard. Both apps are React + TypeScript + Vite
frontends on Supabase, with row-level security, storage, SQL triggers and edge functions.

- Public site: listings, agents, search/filters, map, WhatsApp inquiries, reservation deposits
- Admin app: email/password sign-in, profile roles and permissions, listings, inquiries, payments,
  agents, users, reports, settings
- Brand: deep green `#0b2e25` + gold `#c9a227`; wordmark is always **LINK-LAND**

---

## Contents

- [Project structure](#project-structure)
- [Quick start](#quick-start)
- [Supabase setup](#supabase-setup)
- [Admin access and roles](#admin-access-and-roles)
- [Features](#features)
- [Payments](#payments)
- [Edge functions](#edge-functions)
- [Deployment](#deployment)
- [Environment variables](#environment-variables)
- [Security notes](#security-notes)
- [Useful commands](#useful-commands)
- [Troubleshooting](#troubleshooting)

---

## Project structure

```
LINK-LAND/
├─ apps/
│  ├─ website/                 Public marketplace (Netlify site 1)
│  │  ├─ netlify.toml          package directory: apps/website
│  │  ├─ netlify/edge-functions/og-meta.ts
│  │  └─ src/
│  └─ admin/                   Private dashboard (Netlify site 2)
│     ├─ netlify.toml          package directory: apps/admin
│     └─ src/
├─ supabase/
│  ├─ schema.sql               Tables, profiles/RLS, triggers, RPCs, storage policies
│  ├─ upgrade-profiles.sql     Migration for an existing Google/allow-list database
│  ├─ seed.sql                 Settings, payment methods, demo agents/listings
│  ├─ config.toml              Edge function JWT settings
│  └─ functions/
│     ├─ _shared/              cors, admin client, HMAC helpers
│     ├─ admin-users/          Super-admin user, role and password management
│     ├─ create-payment/       Provider checkout (disabled by default)
│     ├─ payment-webhook/      Signed provider callback
│     └─ expire-featured/      Cron job for expired featured listings
├─ scripts/
│  └─ create-super-admin.mjs   Creates the first Auth user + super admin profile
├─ package.json                npm workspaces + scripts
└─ README.md
```

Node **20+** is required.

---

## Quick start

```bash
npm install
cp apps/website/.env.example apps/website/.env
cp apps/admin/.env.example apps/admin/.env
# fill both .env files with your Supabase URL and anon key
npm run dev:website   # http://localhost:5173
npm run dev:admin     # http://localhost:5174, run in a second terminal
```

Typecheck and production build:

```bash
npm run typecheck
npm run build
```

The website renders an offline/empty state in development without Supabase. Production builds
validate the required authentication variables and fail fast instead of deploying a broken app.

---

## Supabase setup

### 1. Create a project

Create a project at https://supabase.com, then copy:

- Project URL → `VITE_SUPABASE_URL`
- `anon` public key → `VITE_SUPABASE_ANON_KEY`

Never put the `service_role` key in either frontend env file.

### 2. Create the schema

In the Supabase SQL Editor, run the entire contents of `supabase/schema.sql`.
It creates:

- `profiles` (Auth-linked accounts and roles), `agents`, `listings`, `listing_images`,
  `inquiries`, `payments`, `settings`, `payment_settings`
- Legacy `admins` table (kept for migration only; the app uses `profiles`)
- Row-level security policies for public, agent and staff access
- Guard triggers (agents cannot self-approve listings; payments apply listing side effects;
  the last active super admin cannot be removed)
- Storage buckets `listing-images` (public) and `payment-proofs` (private)
- RPCs: `submit_payment`, `increment_listing_views`, `expire_featured_listings`,
  `bootstrap_super_admin`

If your project already used the old Google allow-list schema, run
`supabase/upgrade-profiles.sql` instead, then create the first super admin below.

### 3. Seed settings and demo data

Run `supabase/seed.sql`. It is safe to re-run.

### 4. Create the super admin

The account is `ishanews7@gmail.com`. Passwords are stored only by Supabase Auth, never in SQL
or the database. Run this from the repo root with your project URL and service-role key:

```bash
# PowerShell
$env:SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="YOUR-SERVICE-ROLE-KEY"
$env:SUPER_ADMIN_PASSWORD="choose-a-strong-password"
npm run create-super-admin
```

```bash
# macOS/Linux
SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=... \
SUPER_ADMIN_PASSWORD=... \
npm run create-super-admin
```

The script creates or updates the Auth user and upserts an active `super_admin` profile. It uses
`SUPER_ADMIN_EMAIL` if set; otherwise the default is `ishanews7@gmail.com`. Never commit the
service-role key or the password.

If you prefer SQL, first create the user in Authentication → Users, then run in the SQL Editor:

```sql
select public.bootstrap_super_admin('ishanews7@gmail.com');
```

### 5. Configure email/password auth

In Supabase Dashboard → Authentication → Providers → Email:

1. Enable Email.
2. Turn off **Allow new users to sign up**. Accounts are created by a super admin from the
   **Users** page or by the script above.
3. Keep email confirmation enabled for production; the admin script creates users pre-confirmed.

In Supabase → Authentication → URL Configuration:

- **Site URL**: the public website URL, e.g. `https://link-land.netlify.app`
- **Redirect URLs**: add every website/admin origin you use, e.g.
  `https://link-land.netlify.app/**`, `https://link-land-admin.netlify.app/**`,
  `https://link-land-admin.netlify.app/login`, `https://link-land-admin.netlify.app/admin/login`,
  `http://localhost:5173/**`, `http://localhost:5174/**`

The admin app signs in against Supabase Auth, then reads the caller's `profiles` row. Unknown,
inactive or `user` accounts see **Ma haysatid ogolaansho** and are signed out immediately.

### 6. Storage

`schema.sql` creates both buckets and their policies. Confirm in Storage:

- `listing-images` — public read, staff/agent write
- `payment-proofs` — private; admins read via short-lived signed URLs

If your project already has buckets with these names, verify the policies match `schema.sql`.

---

## Admin access and roles

Access is account based. A user must:

1. Sign in with an email and password stored in Supabase Auth.
2. Have a matching `public.profiles` row with `is_active = true` and a dashboard role.

Roles and permissions:

| Role | Access |
| --- | --- |
| `super_admin` | Everything: listings, inquiries, payments, agents, reports, users, permissions, settings |
| `admin` | Listings, inquiries, payments, agents, reports; no users/settings/permissions |
| `manager` | Listings, inquiries, payments, reports; no agents/users/settings/permissions |
| `staff` | Listings and inquiries only |
| `agent` | Own listings, inquiries, payments and profile; listing edits return to `pending` |
| `user` | No dashboard access (signed out with **Ma haysatid ogolaansho**) |

The matrix lives in `apps/admin/src/lib/constants.ts` and is mirrored by Postgres RLS/triggers, so
it cannot be bypassed from the browser. Only a super admin can create accounts, assign roles,
disable users or reset passwords, through the `admin-users` edge function.

Dashboard routes are protected under `/admin/*`: `/admin/dashboard`, `/admin/listings`,
`/admin/inquiries`, `/admin/payments`, `/admin/agents`, `/admin/reports`, `/admin/users`,
`/admin/permissions`, `/admin/settings` and `/admin/profile`. The login pages are `/login` and
`/admin/login`.

**Hidden entrance:** the public site deliberately has no visible admin link. Use any of:

- `Ctrl/Cmd + Shift + A` (configurable in `apps/website/src/lib/constants.ts`)
- `Ctrl + Alt + A` as an alternative
- Tap the LINK-LAND logo 5 times within 3 seconds
- Open the admin URL directly

Set `VITE_ADMIN_URL` on the website to the admin site root; the shortcut opens
`/admin/dashboard` directly. Without an admin session, the dashboard guard sends the user to
`/login`, and signing in with the Supabase Auth email and password returns them to the dashboard.

---

## Features

### Public website (`apps/website`)

- Somali default language with English toggle; all copy is bilingual
- Home page with hero search, featured listings, categories, stats, how-it-works, agents and CTA
- Listings index with search, city/district, type, purpose, price range, bedrooms, sorting and pagination
- Listing detail with image gallery, map, price, features, agent card, WhatsApp/call actions and inquiry form
- Reserve flow: mobile-money instructions (EVC Plus, eDahab, Zaad, cash, bank), transaction ID,
  optional proof upload, `submit_payment` RPC
- Agents index and agent profile with their published listings
- About, Contact, FAQ and NotFound pages
- View counter RPC and JSON-LD structured data
- Netlify Edge function injects Open Graph/Twitter meta for shared listing links
- Supabase client uses `persistSession: false` — public visitors are never signed in

### Admin dashboard (`apps/admin`)

- Email/password login with profile-role verification and clear Somali denial message
- Dashboard: listing/agent/inquiry/payment counts, revenue, charts and recent activity
- Listings: create/edit/delete, image upload with cover selection, approve, reject, feature/unfeature,
  filter by status/purpose/type/city, agent ownership
- Inquiries: read, mark status, WhatsApp/call, delete, CSV export
- Payments: filter, detail drawer, private proof signed URL, confirm/reject/refund, notes,
  record manual payment, print receipt, CSV export
- Agents: super-admin CRUD, verified/active toggles, photo upload; staff can view
- Users & roles: super-admin creates Auth accounts, assigns roles, disables users, resets passwords
  and deletes accounts through the `admin-users` edge function
- Reports: 6-month activity, listing status, top cities, confirmed revenue, payment CSV export
- Permissions: read-only permission matrix and database-enforcement summary
- Settings: brand, taglines, contact/social links, about/footer, default currency and fees
- Profile: agents update their own agent profile; edits are re-checked server-side
- Admin app is `noindex, nofollow`, `robots.txt` disallows all, and security headers deny framing

---

## Payments

Manual mobile-money reservation is the primary flow. A visitor selects a listing, pays the
deposit to the displayed merchant number, enters the transaction ID and optionally uploads a
proof screenshot. `submit_payment` validates the amount against `settings.deposit_amount` and
stores only the proof path; admins review it using signed URLs.

`payments_apply_status` applies side effects automatically:

- `confirmed` deposit → listing becomes `reserved`
- `confirmed` featured boost → listing becomes `featured` for `settings.featured_days`
- refund/reject updates the record without deleting history

The database also enforces:

- Amounts for `deposit`, `listing_fee` and `featured_boost` are computed from settings
- Clients cannot choose arbitrary prices or inject provider data
- Agents only see their own payments

Optional online checkout (`create-payment`) and signed callbacks (`payment-webhook`) are
included but **disabled by default**. See below.

---

## Edge functions

Location: `supabase/functions/`

| Function | JWT | Purpose |
| --- | --- | --- |
| `admin-users` | verified | Super-admin-only Auth account, role and password management |
| `create-payment` | verified | Server-side checkout creation; amounts come from settings |
| `payment-webhook` | **disabled** | HMAC-signed provider callback; updates payment status |
| `expire-featured` | **disabled** | Cron job calling `expire_featured_listings()` |

### Configure secrets

```bash
cp supabase/functions/.env.example supabase/functions/.env
# edit the file, then push secrets
supabase secrets set --env-file supabase/functions/.env
```

### Deploy

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy admin-users
supabase functions deploy create-payment
supabase functions deploy payment-webhook --no-verify-jwt
supabase functions deploy expire-featured --no-verify-jwt
```

`supabase/config.toml` already sets `verify_jwt` correctly for the Supabase CLI.

### Webhook signature

`payment-webhook` expects:

- `x-linkland-timestamp`: Unix seconds, within 5 minutes of now
- `x-linkland-signature`: `sha256=<hex HMAC-SHA256 of "{timestamp}.{rawBody}">`
- Secret: `PAYMENT_WEBHOOK_SECRET`

The body may use `payment_id` or `reference`, plus `provider`, `provider_txn_id`, `status`
and optional `notes`. Statuses are normalized:

- `success`, `succeeded`, `paid`, `complete`, `completed`, `confirmed` → `confirmed`
- `failed`, `cancelled`, `canceled`, `rejected` → `rejected`
- `refunded` → `refunded`

Replays are idempotent by `provider + provider_txn_id`.

### Online provider setup

`create-payment` returns `503` unless `PAYMENT_PROVIDER_ENABLED=true`. Supported adapters:

- `waafipay` — requires `WAAFI_MERCHANT_UID`, `WAAFI_API_USER_ID`, `WAAFI_API_KEY`
- `stripe` — requires `STRIPE_SECRET_KEY`

The response contains `checkout_url`; redirect the visitor there. Only `deposit` is public.
`listing_fee` and `featured_boost` require an active admin session.

Always send real provider callbacks to `payment-webhook`, never trust a browser redirect.

### Featured expiry cron

Schedule a POST request to `/functions/v1/expire-featured` with header
`x-cron-secret: <CRON_SECRET>`. You can also pass a service-role bearer token.
Use Supabase Cron, GitHub Actions, or any scheduler.

---

## Deployment

### Netlify — two sites from one repo

Deploy **both** apps. The public website and admin dashboard are separate Vite applications,
both connected to the same Supabase project. Deploying only one leaves the other unavailable.

The production build fails with a clear error if required `VITE_*` variables are missing. This
prevents a deployment that silently falls back to placeholder Supabase configuration.

#### Site 1 — public website

| Netlify setting | Value |
| --- | --- |
| Base directory | leave at the repository root |
| Package directory | `apps/website` |
| Build command | `npm run build:website` |
| Publish directory | `apps/website/dist` |
| Config file | `apps/website/netlify.toml` |
| Node | `20` |

Required environment variables:

```dotenv
VITE_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR-SUPABASE-PUBLISHABLE-OR-ANON-KEY
VITE_SITE_URL=https://YOUR-SITE.netlify.app
VITE_ADMIN_URL=https://YOUR-ADMIN-SITE.netlify.app
```

Optional: `VITE_DEFAULT_WHATSAPP=+252617179076`.

For the `/listings/*` Open Graph edge function, also add:

```dotenv
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY=YOUR-SUPABASE-PUBLISHABLE-OR-ANON-KEY
```

`VITE_SITE_URL` is required unless Netlify’s built-in `URL`/`DEPLOY_PRIME_URL` is available.
`VITE_ADMIN_URL` is always required in production. Do not include a trailing slash or
`/admin/dashboard`; the shortcut appends the dashboard path itself.

#### Site 2 — admin dashboard

| Netlify setting | Value |
| --- | --- |
| Base directory | leave at the repository root |
| Package directory | `apps/admin` |
| Build command | `npm run build:admin` |
| Publish directory | `apps/admin/dist` |
| Config file | `apps/admin/netlify.toml` |
| Node | `20` |

Required environment variables:

```dotenv
VITE_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR-SUPABASE-PUBLISHABLE-OR-ANON-KEY
VITE_PUBLIC_SITE_URL=https://YOUR-SITE.netlify.app
```

`VITE_PUBLIC_SITE_URL` must be the public website origin, not the admin origin. It is used for
“view listing” links and WhatsApp shares.

#### Configuration rules

- Keep the Netlify **base directory** at the repository root and set the **package directory**
  to the app folder. This lets Netlify install the npm workspace from the root lockfile while
  reading each app’s `netlify.toml`.
- Set variables in **Netlify → Site configuration → Environment variables**, for the matching
  site. Variables are not shared automatically between the two Netlify sites.
- Set them for the **production** scope (and deploy-preview/branch scopes if needed).
- `.env` files are local only and are gitignored; do not upload them and do not rely on them in
  Netlify.
- Use only the Supabase URL and publishable/anon key in browser env vars. Never add the
  `service_role` key to Netlify or any `VITE_*` variable.
- The website and admin configs already provide SPA fallback (`/* → /index.html`), asset
  caching, security headers, and admin `noindex` headers.
- Redeploy after changing environment variables. Vite embeds `VITE_*` values at build time.

#### Supabase backend + Auth

The frontend env vars connect the browsers to the existing Supabase project. They do not deploy
your database policies, storage buckets, or edge functions.

1. Apply the required SQL, including `supabase/fix-inquiries-publishing.sql`, in the Supabase
   SQL Editor.
2. Deploy the edge functions with the Supabase CLI:
   `admin-users`, `create-payment`, `payment-webhook`, and `expire-featured`. See
   [Edge functions](#edge-functions).
3. Set the function secrets from `supabase/functions/.env.example` in Supabase, not Netlify.
4. In Supabase → Authentication → URL Configuration, set:
   - **Site URL**: `https://YOUR-SITE.netlify.app`
   - **Redirect URLs**: `https://YOUR-SITE.netlify.app/**`,
     `https://YOUR-ADMIN-SITE.netlify.app/**`,
     `https://YOUR-ADMIN-SITE.netlify.app/login`,
     `https://YOUR-ADMIN-SITE.netlify.app/admin/login`,
     and the equivalent custom-domain URLs when used.
5. Confirm the admin login account exists in Supabase Auth and its `profiles` row is
   `super_admin` and active.

#### Production smoke test

After both deploys complete, test the production URLs, not just the local dev servers:

- Public site: home, listings, filters, listing detail, agents, contact/FAQ, direct refresh of
  a nested route (should be a 200, not a Netlify 404).
- Admin: open the website shortcut, confirm it reaches the admin site, sign in, refresh the
  dashboard, open listings/inquiries/payments/reports/users, then sign out.
- Database: create a listing as staff, confirm it is immediately visible on the public site,
  submit a public inquiry, then confirm it appears in the admin Inquiries page.
- Storage: upload listing images and a payment proof; confirm public image URLs and admin signed
  proof URLs load.
- API/backend: use the Users page (requires deployed `admin-users`), update settings, and test
  any enabled payment flow.
- Browser console: no missing-env errors, failed Supabase/CORS requests, redirect loops, or 404
  assets.

---

## Environment variables

### `apps/website/.env`

| Key | Required | Description |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | yes | Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | yes | Supabase publishable/anon key |
| `VITE_SITE_URL` | yes* | Canonical public origin; falls back to Netlify’s `URL` |
| `VITE_ADMIN_URL` | yes | Admin site root for the hidden shortcut |
| `VITE_DEFAULT_WHATSAPP` | no | Fallback WhatsApp number |

\* Required in production unless Netlify provides its built-in `URL`/`DEPLOY_PRIME_URL`.

### `apps/admin/.env`

| Key | Required | Description |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | yes | Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | yes | Supabase publishable/anon key |
| `VITE_PUBLIC_SITE_URL` | yes | Public site origin for listing links/shares |

### `supabase/functions/.env` (server-only)

See `supabase/functions/.env.example`. Includes service role key, webhook/cron secrets and
optional WaafiPay/Stripe credentials. Set these as Supabase edge-function secrets. Never expose
them to a frontend or Netlify.

---

## Security notes

- RLS is enabled on every table. Public users can only read published content and insert inquiries.
- Admin identity is checked from the Auth session **and** the active `profiles` role in Postgres;
  UI guards are convenience only.
- Passwords exist only in Supabase Auth. They are never written to a table or returned by the app.
- Agents cannot approve their own listings, change ownership, or see other agents' records.
- Payment amounts are server/database-controlled; browser input is ignored.
- `payment-proofs` is private; admins use short-lived signed URLs.
- Webhook callbacks require HMAC verification with a timestamp window and idempotency key.
- Admin app is excluded from search engines and cannot be framed.
- Never commit `.env` files or the service-role key.

---

## Useful commands

```bash
npm run dev:website
npm run dev:admin
npm run typecheck
npm run build
npm run build:website
npm run build:admin
npm run create-super-admin
```

---

## Troubleshooting

**Website shows no listings**
Run `schema.sql` + `seed.sql`, confirm listings are `published`, and check the browser console
for Supabase auth/RLS errors.

**Invalid email or password**
Confirm the user exists in Authentication → Users and that the password is current. If the account
was created directly in the dashboard without a `profiles` row, create the profile or use
`npm run create-super-admin`.

**"Ma haysatid ogolaansho"**
The signed-in account has no active `profiles` row, is disabled, or has the `user` role. A super
admin can fix this on the **Users** page, or run
`select public.bootstrap_super_admin('ishanews7@gmail.com');` after the Auth user exists.

**User creation fails**
Deploy the `admin-users` function and confirm `SUPABASE_SERVICE_ROLE_KEY` is set as a function
secret. Only an active `super_admin` can call it.

**Images fail to upload**
Confirm the `listing-images` bucket exists, is public, and the user has an active profile with
the right role. Check storage policies from `schema.sql`.

**Payment proof cannot be opened**
Proofs are private. Use the admin payments detail view, which requests a signed URL; never make
the bucket public.

**Typecheck fails after editing edge functions**
Edge functions use Deno APIs and are intentionally outside the npm TypeScript workspace.
Use `deno check` or deploy with the Supabase CLI.
