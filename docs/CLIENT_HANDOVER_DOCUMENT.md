# Balaji Automobiles — Project Handover & Technical Blueprint
**Client Executive Document | Version 1.0.0 (Production Ready)**  
**Generated for:** Balaji Automobiles (`balajiautomobiles088@gmail.com`)  
**Project:** Balaji Garage (Workshop Console), Balaji Car (Customer App), Public Portal & Supabase Cloud Backend

---

## Table of Contents
1. [Executive Summary & System Architecture](#1-executive-summary--system-architecture)
2. [Master Credentials & Access Vault](#2-master-credentials--access-vault)
3. [Backend Notification System (3-Tier Engine)](#3-backend-notification-system-3-tier-engine)
4. [Complete API & RPC Reference](#4-complete-api--rpc-reference)
5. [Database Schema & Entity Models](#5-database-schema--entity-models)
6. [Step-by-Step Dashboard Setup & "What to Paste Where"](#6-step-by-step-dashboard-setup--what-to-paste-where)
7. [Role-Based Access Control (RBAC) & Team Management](#7-role-based-access-control-rbac--team-management)
8. [GST Engine & Invoice Templates](#8-gst-engine--invoice-templates)
9. [Release Artifacts & Client Deliverables](#9-release-artifacts--client-deliverables)
10. [Troubleshooting, Health Checks & Maintenance](#10-troubleshooting-health-checks--maintenance)

---

## 1. Executive Summary & System Architecture

Balaji Automobiles is a complete automotive workshop management ecosystem consisting of:
- **Balaji Garage (Admin Console App):** Built for the garage owner, managers, accountants, storekeepers, and mechanics. Handles complete job card workflows, counter billing, staff attendance, customer directories, inventory masters, and GST reports. Runs **offline-first** on local SQLite/Isar cache and syncs seamlessly with the cloud.
- **Balaji Car (Customer Mobile App):** Allows vehicle owners to book service appointments, locate nearby authorized garages via GPS, track live job card progress in real-time, inspect itemized estimates, and review billing history.
- **WhatsApp Instant Job Card Web Portal (`/j/:token`):** A zero-install web link sent via WhatsApp that lets customers inspect their live repair bill and service stage directly in any web browser without needing to sign up or download an app.
- **Supabase Cloud Backend:** Centralized PostgreSQL database featuring Row Level Security (RLS), Realtime WebSocket publications, database triggers, and Edge Functions.
- **Firebase Cloud Messaging (FCM):** Background push notification engine for instant audio and heads-up banner notifications on Android handsets.

### High-Level Architecture Flowchart

```
┌────────────────────────────────────────────────────────────────────────┐
│                        BALAJI AUTOMOBILES ECOSYSTEM                     │
└────────────────────────────────────────────────────────────────────────┘

    [ Customer App: Balaji Car ]             [ Workshop Console: Balaji Garage ]
  (com.balajiautomobiles.customer)             (com.balajiautomobiles.garage)
                 │                                            │
                 │ (Deep Link: login-callback)                │ (Deep Link: login-callback)
                 ▼                                            ▼
      ┌──────────────────────────────────────────────────────────────┐
      │                   GOOGLE CLOUD OAUTH 2.0                     │
      │   Client ID: 787349507364-b943fq2sf47h2eqa3chiuck7923q7gv7   │
      └──────────────────────────────┬───────────────────────────────┘
                                     │ Auth ID Token
                                     ▼
      ┌──────────────────────────────────────────────────────────────┐
      │             SUPABASE CLOUD (PostgreSQL 15 + RLS)             │
      │              Project: zlrmcrhwtfbwbxhfmygs                   │
      ├──────────────────────────────────────────────────────────────┤
      │ • Auth & User Management (JWT Bearer / Session Tokens)       │
      │ • Realtime WebSocket Engine (channel: garage:<id>)           │
      │ • Row Level Security (RLS) - Data Isolation per Workshop     │
      │ • Atomic RPC Procedures (save_job_card, garage_snapshot)     │
      └──────────────┬───────────────────────────────┬───────────────┘
                     │                               │
        Database Trigger on INSERT      Database Trigger on INSERT
       (public.garage_notifications)    (public.customer_alerts)
                     │                               │
                     └───────────────┬───────────────┘
                                     │ Database Webhook (x-webhook-secret)
                                     ▼
      ┌──────────────────────────────────────────────────────────────┐
      │         SUPABASE EDGE FUNCTION: notify-garage                │
      │               (Deno Runtime / TypeScript)                    │
      └──────────────────────────────┬───────────────────────────────┘
                                     │ FCM v1 HTTP API (OAuth Token)
                                     ▼
      ┌──────────────────────────────────────────────────────────────┐
      │              FIREBASE CLOUD MESSAGING (FCM)                  │
      │        High-Priority OS Notification Delivery Engine         │
      └──────────────┬───────────────────────────────┬───────────────┘
                     │                               │
                     ▼                               ▼
         [ Workshop Handset ]              [ Customer Handset ]
      - High Alert Chime                 - Heads-up Notification
      - Channel: garage_booking_v1       - Channel: customer_updates_v1
      - Auto-navigates to /bookings      - Auto-navigates to /job-card
```

---

## 2. Master Credentials & Access Vault

> [!IMPORTANT]
> Keep this section secure. The credentials below grant master administrative access across the platform, database, and client applications.

### 2.1 Primary Master & Super Admin Account
This is the primary login configured for the client workshop owner. It holds Super Admin rights across the platform directory and owns the Balaji Automobiles workshop in the database.

| Parameter | Value | Notes |
|---|---|---|
| **Master Email** | `balajiautomobiles088@gmail.com` | Primary Owner & Platform Head |
| **Master Password** | `automobiles@088*` | Set via Supabase Auth / Bcrypt |
| **Account Type** | Platform Super Admin + Workshop Owner | Full administrative privileges |
| **Secondary Super Admin** | `vjalaria@gmail.com` | Lead developer recovery account |
| **Workshop Phone** | `9462153613` / `9269297999` | Contact phone for workshop |
| **Workshop PIN Code** | `333503` | Postal code for geographic radius |
| **Default GPS Coordinates** | `30.7333, 76.7794` | Can be updated via "Use Current Location" |
| **UPI ID for Payments** | `balajiauto@okicici` | Built into invoice dynamic QR code |

### 2.2 Supabase Cloud Backend Infrastructure
The central PostgreSQL database, auth server, and realtime gateway:

| Parameter | Configuration Value |
|---|---|
| **Project Name** | GaragePro / Balaji Automobiles |
| **Project Ref / ID** | `zlrmcrhwtfbwbxhfmygs` |
| **Dashboard URL** | `https://supabase.com/dashboard/project/zlrmcrhwtfbwbxhfmygs` |
| **API Base URL** | `https://zlrmcrhwtfbwbxhfmygs.supabase.co` |
| **Publishable (Anon) Key** | `sb_publishable_IJGQOXtE8tr7b_IgIi5cdQ_wDs6oFl7` |
| **Client Safety Note** | The Anon key is safe inside apps. Row-Level Security (RLS) protects all data. |
| **Secret / Service Role Key** | Keep in dashboard only! Never embed in mobile or web clients. |

### 2.3 Google Cloud Platform & OAuth 2.0
Used for native Android one-tap Google Sign-in:

| Parameter | Value | Purpose |
|---|---|---|
| **Web OAuth Client ID** | `787349507364-b943fq2sf47h2eqa3chiuck7923q7gv7.apps.googleusercontent.com` | Supabase OAuth provider & app config |
| **Authorised Redirect URI** | `https://zlrmcrhwtfbwbxhfmygs.supabase.co/auth/v1/callback` | Google Cloud Web Client setting |
| **Release / Debug SHA-1** | `83:99:64:B6:0E:36:1D:AB:E1:92:2A:F5:8D:BC:41:21:0B:20:19:41` | Keystore fingerprint in Google Cloud |
| **Admin Android Package** | `com.garagepro.garagepro_admin` (or `com.balajiautomobiles.garage`) | Workshop Console Package |
| **Customer Android Package** | `com.garagepro.garagepro` (or `com.balajiautomobiles.customer`) | Customer App Package |

### 2.4 Web Portal & Hosting Links
| Channel | Destination URL | Details |
|---|---|---|
| **Official Public Website** | `https://balajiautomobiles.in` | Public landing page, features & contact |
| **Customer APK Download Site** | `https://balaji-automobiles-apps.netlify.app` | Netlify direct app installation portal |
| **Shared Job Card Endpoint** | `https://balajiautomobiles.in/j/<token>` | Live invoice link shared on WhatsApp |
| **Support Email** | `support@balajiautomobiles.in` | Official customer support inbox |

---

## 3. Backend Notification System (3-Tier Engine)

The notification system guarantees that the workshop and customer never miss an important event, whether the app is active on screen, running in the background, or completely shut down.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   3-TIER NOTIFICATION ARCHITECTURE                     │
├─────────────────┬───────────────────┬──────────────────────────────────┤
│ Console State   │ Delivery Channel  │ Infrastructure Dependency        │
├─────────────────┼───────────────────┼──────────────────────────────────┤
│ 1. Open on screen│ In-App Banner     │ Supabase Realtime WebSocket      │
│ 2. Open later   │ Bell Feed Badge   │ Table: public.garage_notifications│
│ 3. Closed / OS  │ Tray Audio Push   │ Supabase Edge Function + FCM     │
└─────────────────┴───────────────────┴──────────────────────────────────┘
```

### 3.1 Layer 1: In-App Foreground Banner
- **Trigger:** Immediate WebSocket broadcast over Supabase channel `garage:<id>`.
- **Implementation:** `AlertHost` (`lib/core/widgets/alert_host.dart`) wraps `MaterialApp.builder`.
- **Behavior:** When a booking arrives, an elegant persistent top banner slides down over any current view (including modals, dialogs, or camera sheets) without interrupting user input.

### 3.2 Layer 2: Durable Database Feed & Unread Bell
- **Trigger:** Automatic PostgreSQL trigger `garage_bookings_notify` on table `public.garage_bookings`.
- **Target Table:** `public.garage_notifications` (for workshop) and `public.customer_alerts` (for customer).
- **Security Rule:** Neither clients nor the owner can directly insert, update, or delete notification rows. Notifications are tamper-proof records created exclusively by PostgreSQL triggers.
- **Marking as Read:** Handled by secure RPC `public.read_garage_notifications(ids text[])`.

### 3.3 Layer 3: Background OS Push Notifications (FCM + Supabase Edge Functions)
When the console or customer phone is locked or closed, Google FCM delivers a heads-up banner with custom sound.

#### Execution Pipeline:
1. An event occurs (e.g. customer confirms booking or workshop marks vehicle ready).
2. Database trigger inserts a row into `public.garage_notifications` or `public.customer_alerts`.
3. Supabase **Database Webhook** fires an HTTP POST payload to Edge Function `notify-garage`.
4. The Edge Function verifies the `x-webhook-secret` header.
5. The Edge Function fetches the registered device tokens from `garage_devices` or `customer_devices`.
6. The Edge Function authenticates with Google via the `FCM_SERVICE_ACCOUNT` private key and dispatches an FCM v1 HTTP message.
7. The Android OS receives the push on the designated channel and plays the specific chime.

#### Android Notification Channels Configuration

| Channel ID | App Target | Sound / Chime | Importance | Purpose |
|---|---|---|---|---|
| `garage_booking_v1` | Workshop Console | High alert chime | HIGH (Heads-up) | New booking requested by customer |
| `garage_payment_v1` | Workshop Console | Payment chime | HIGH (Heads-up) | Payment recorded / settlement |
| `garage_reminder_v1`| Workshop Console | Standard tone | DEFAULT | Vehicle service due reminder |
| `garage_general_v1` | Workshop Console | Notification tone | DEFAULT | Reviews, inquiries, announcements |
| `customer_updates_v1`| Customer App | Friendly chime | HIGH (Heads-up) | Vehicle ready, booking confirmed/declined |

> [!WARNING]
> Android permanently freezes notification channel sounds upon initial handset creation. If you ever update notification sounds in the code, you must increment the channel version suffix (e.g. from `garage_booking_v1` to `garage_booking_v2`).

---

## 4. Complete API & RPC Reference

All backend communication utilizes Supabase's high-performance PostgREST and Remote Procedure Call (RPC) architecture. Every request requires the `apikey` and `Authorization` headers.

### Base URLs
- **REST & RPC Base:** `https://zlrmcrhwtfbwbxhfmygs.supabase.co/rest/v1`
- **Auth Base:** `https://zlrmcrhwtfbwbxhfmygs.supabase.co/auth/v1`
- **Edge Functions Base:** `https://zlrmcrhwtfbwbxhfmygs.supabase.co/functions/v1`

---

### 4.1 Core Workshop RPCs

#### `POST /rest/v1/rpc/save_job_card`
**Description:** Atomic single-transaction save for job cards, line items, payments, and timeline logs. Prevents partial saves during unstable network connections.
- **Authentication:** Bearer JWT (`authenticated` role, staff or owner)
- **Request Headers:**
  ```http
  apikey: sb_publishable_IJGQOXtE8tr7b_IgIi5cdQ_wDs6oFl7
  Authorization: Bearer <USER_JWT_TOKEN>
  Content-Type: application/json
  ```
- **Payload (`payload` jsonb):**
  ```json
  {
    "card": {
      "id": "A1018-001",
      "garage_id": "00000000-0000-0000-0000-000000000000",
      "customer_id": "cust_12345",
      "vehicle_id": "veh_67890",
      "status": "open",
      "km_reading": 45200,
      "fuel_level": "50%",
      "promised_at": "2026-10-20T17:00:00Z",
      "tax_rate": 0.18,
      "discount": 200.00
    },
    "items": [
      {
        "id": "item_1",
        "description": "Engine Oil 5W30 Synthetic",
        "hsn": "2710",
        "qty": 3.5,
        "rate": 650.00,
        "is_labour": false
      },
      {
        "id": "item_2",
        "description": "General Periodic Service Labour",
        "hsn": "9987",
        "qty": 1.0,
        "rate": 800.00,
        "is_labour": true
      }
    ],
    "payments": [
      {
        "id": "pay_1",
        "amount": 500.00,
        "mode": "UPI",
        "reference": "UPI/20261018/123456"
      }
    ]
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "card_id": "A1018-001",
    "updated_at": "2026-10-18T12:55:00Z"
  }
  ```

---

#### `POST /rest/v1/rpc/garage_snapshot`
**Description:** Fetches the entire workshop state (job cards, inventory masters, customers, team members) for offline-first caching. Automatically filters data according to the caller's role (mechanics see only assigned cards; managers see no profit margins).
- **Parameters:** `{"gid": "<GARAGE_UUID>"}`
- **Response Structure:**
  ```json
  {
    "garage": { "id": "...", "name": "Balaji Automobiles", "gstin": "08ABCDE1234F1Z5" },
    "job_cards": [ ... ],
    "customers": [ ... ],
    "vehicles": [ ... ],
    "inventory": [ ... ],
    "staff": [ ... ]
  }
  ```

---

#### `POST /rest/v1/rpc/read_garage_notifications`
**Description:** Marks one or more notification records as read across all counter handsets simultaneously.
- **Parameters:** `{"ids": ["notif_uuid_1", "notif_uuid_2"]}`
- **Response:** `204 No Content` (or `true`)

---

#### `POST /rest/v1/rpc/punch_attendance`
**Description:** Records employee attendance clock-in / clock-out with biometric / GPS geofencing verification against workshop latitude/longitude.
- **Parameters:**
  ```json
  {
    "payload": {
      "garage_id": "<GARAGE_UUID>",
      "staff_id": "<STAFF_UUID>",
      "punch_type": "in",
      "lat": 30.7333,
      "lng": 76.7794,
      "device_timestamp": "2026-10-18T09:30:00Z"
    }
  }
  ```
- **Response:**
  ```json
  {
    "status": "success",
    "distance_meters": 12.4,
    "verified": true
  }
  ```

---

### 4.2 Customer App & Public Web RPCs

#### `POST /rest/v1/rpc/shared_card`
**Description:** **Public Anonymous RPC.** Used by `https://balajiautomobiles.in/j/:token` to render the live repair bill and status for a WhatsApp customer without authentication. Returns public invoice fields while stripping internal workshop cost prices, mechanic names, and private notes.
- **Authentication:** Anon Key (`sb_publishable_...`)
- **Parameters:** `{"tok": "<192_BIT_SECURE_SHARE_TOKEN>"}`
- **Response:**
  ```json
  {
    "number": "A1018-001",
    "status": "open",
    "created_at": "2026-10-18T10:00:00Z",
    "promised_at": "2026-10-20T17:00:00Z",
    "garage": {
      "name": "Balaji Automobiles",
      "phone": "9462153613",
      "address": "Sector 15, Chandigarh"
    },
    "vehicle": {
      "brand": "Maruti Suzuki",
      "model": "Swift",
      "reg_no": "RJ18AB1234"
    },
    "items": [
      { "description": "Engine Oil 5W30", "qty": 3.5, "rate": 650.00 },
      { "description": "Periodic Service Labour", "qty": 1.0, "rate": 800.00 }
    ],
    "discount": 200.00,
    "tax_rate": 0.18,
    "paid": 500.00
  }
  ```

---

#### `POST /rest/v1/rpc/nearby_garages`
**Description:** Finds listed and verified garages near a customer's GPS coordinate within a given radius.
- **Parameters:**
  ```json
  {
    "in_lat": 30.7333,
    "in_lng": 76.7794,
    "radius_km": 15,
    "q": null
  }
  ```
- **Response:**
  ```json
  [
    {
      "id": "garage_uuid",
      "name": "Balaji Automobiles",
      "phone": "9462153613",
      "city": "Chandigarh",
      "address": "Sector 15, Chandigarh",
      "km": 1.25,
      "verified": true,
      "listed": true
    }
  ]
  ```

---

#### `POST /rest/v1/rpc/issue_customer_code` & `redeem_customer_code`
**Description:** Secure counter-to-customer phone handshake.
1. Workshop clicks **Link App** on a customer record → calls `issue_customer_code(cid)` → generates 6-digit PIN (valid for 24 hours).
2. Customer enters code in **Account → Link your workshop** → calls `redeem_customer_code(entered)` → instantly links entire historical service records to customer profile.

---

### 4.3 Push Device Registration RPCs

| RPC Name | Target | Purpose |
|---|---|---|
| `register_garage_device(tok text, plat text)` | Workshop Handsets | Registers workshop FCM token on login |
| `forget_garage_device(tok text)` | Workshop Handsets | Removes token on logout or uninstall |
| `register_customer_device(tok text, plat text)` | Customer Handsets | Registers customer FCM token |
| `forget_customer_device(tok text)` | Customer Handsets | Unregisters customer FCM token on sign-out |

---

### 4.4 Supabase Edge Function: `notify-garage`
- **URL:** `POST https://zlrmcrhwtfbwbxhfmygs.supabase.co/functions/v1/notify-garage`
- **Header:** `x-webhook-secret: <WEBHOOK_SECRET>`
- **Invoked By:** Supabase Database Webhooks on `garage_notifications` and `customer_alerts`.
- **Payload Example:**
  ```json
  {
    "type": "INSERT",
    "table": "garage_notifications",
    "record": {
      "id": "notif_987",
      "garage_id": "garage_uuid",
      "kind": "booking",
      "title": "New Booking Request",
      "body": "Amit Verma booked Full Service for Swift (RJ18AB1234)",
      "route": "/bookings"
    }
  }
  ```
- **Action:** Converts record into Google FCM v1 payload, signs with `FCM_SERVICE_ACCOUNT`, and pushes directly to registered Android tokens. Returns `200 OK`.

---

## 5. Database Schema & Entity Models

The database features 22+ core relational tables secured with PostgreSQL Row Level Security (RLS).

```
                      DATABASE SCHEMA RELATIONSHIPS
                      
    ┌─────────────────┐             ┌─────────────────────┐
    │   auth.users    │ 1─────────1 │   public.profiles   │
    └────────┬────────┘             └──────────┬──────────┘
             │                                 │
             │ 1                               │ 1
             ▼                                 ▼
    ┌─────────────────┐             ┌─────────────────────┐
    │ public.garages  │ 1─────────* │public.garage_members│
    └────────┬────────┘             └─────────────────────┘
             │
             ├─────────────────┬──────────────────┬─────────────────┐
             │ 1               │ 1                │ 1               │ 1
             ▼                 ▼                  ▼                 ▼
    ┌─────────────────┐ ┌──────────────┐ ┌────────────────┐ ┌────────────────┐
    │public.job_cards │ │public.masters│ │public.payments │ │garage_notifica-│
    └────────┬────────┘ └──────────────┘ └────────────────┘ │tions           │
             │                                              └────────────────┘
             ├─────────────────┐
             │ 1               │ 1
             ▼                 ▼
    ┌─────────────────┐ ┌──────────────┐
    │public.line_items│ │public.photos │
    └─────────────────┘ └──────────────┘
```

### Table Dictionary

| Table Name | Description | Key Security / Policy Notes |
|---|---|---|
| `public.garages` | Workshop business records, address, GSTIN, PIN, lat/lng | Read by members; write only by Owner. |
| `public.garage_members` | Staff role assignments (`owner`, `manager`, `mechanic`, `counter`, `accountant`) | Guarded by Super Admin and Owner. |
| `public.profiles` | Universal user profiles linked to `auth.users` | Self-writable only; role changes protected. |
| `public.job_cards` | Primary service tickets with dates, KM, fuel, status, totals | Scoped by workshop. Mechanics see only assigned. |
| `public.line_items` | Parts, oils, and labour items linked to job cards | Scoped to parent job card. |
| `public.payments` | Ledger entries for advances, settlement, UPI/cash | Owner, Manager, Accountant only. |
| `public.garage_customers` | Customer database owned by the workshop | Scoped to workshop ID. |
| `public.garage_vehicles` | Vehicles registered at the workshop | Scoped to workshop ID. |
| `public.garage_devices` | Registered FCM push tokens for workshop handsets | Automatically refreshed on launch. |
| `public.customer_devices` | Registered FCM push tokens for customer handsets | Refreshed on launch; cleared on logout. |
| `public.garage_notifications`| Durable alert feed for workshop bookings and reviews | Inserted ONLY by PostgreSQL triggers. |
| `public.customer_alerts` | Durable alert feed for customer vehicle readiness | Inserted ONLY by PostgreSQL triggers. |
| `public.platform_heads` | Platform Super Admin accounts (Balaji & System Lead) | Editable only via SQL editor. |
| `public.attendance` | Daily staff clock-in / clock-out logs with GPS coordinates | Locked against manual edits. |

---

## 6. Step-by-Step Dashboard Setup & "What to Paste Where"

This section provides the exact copy-paste values required in external dashboards.

### 6.1 Supabase Dashboard Setup

#### A. Auth Configuration
Navigate to: **Authentication → URL Configuration**
Add these 4 Redirect URLs:
```text
com.balajiautomobiles.garage://login-callback
com.balajiautomobiles.customer://login-callback
com.garagepro.garageproadmin://login-callback
com.garagepro.garagepro://login-callback
```

Navigate to: **Authentication → Providers → Email**
- **Enable Email Provider:** ON
- **Confirm email:** OFF during staging/testing (sign in straight away); turn ON for strict production.

#### B. Executing Database Migrations
Navigate to: **SQL Editor → New Query**
Paste and execute in order:
1. `supabase/setup_all.sql` (Creates foundational tables 01 through 10)
2. `supabase/run_18_to_22_together.sql` (Adds vehicle details, platform roles, commission, push notifications)
3. `supabase/run_24_to_26_together.sql` (Applies audit fixes and mandatory PIN search)
4. `supabase/30_super_admins.sql` (Grants Super Admin to `balajiautomobiles088@gmail.com`)
5. `supabase/28_setup_balaji_account.sql` (Confirms owner email, sets password, verifies workshop)

#### C. Setting / Resetting Master Password via SQL
To ensure `balajiautomobiles088@gmail.com` has the exact password `automobiles@088*`, run this snippet in the Supabase SQL editor:
```sql
update auth.users
   set encrypted_password = crypt('automobiles@088*', gen_salt('bf')),
       email_confirmed_at = coalesce(email_confirmed_at, now()),
       updated_at         = now()
 where lower(email) = 'balajiautomobiles088@gmail.com';
```

#### D. Deploying Edge Function `notify-garage`
Navigate to: **Edge Functions → Secrets**
Add the following 2 environment variables:

| Secret Name | Value to Paste | Description |
|---|---|---|
| `WEBHOOK_SECRET` | Generate random 32-hex string (e.g. `9f8e7d6c5b4a3928170f...`) | Shared secret between DB Webhook & Edge Function |
| `FCM_SERVICE_ACCOUNT` | Entire contents of Firebase Service Account JSON | Private key used to sign Google OAuth tokens |

Navigate to: **Edge Functions → Deploy Function**
- Function name: `notify-garage`
- Code: Paste entire `supabase/functions/notify-garage/index.ts`
- **Settings:** Turn **OFF** "Enforce JWT verification" (the function authenticates via `x-webhook-secret`).

#### E. Configuring Database Webhooks
Navigate to: **Database → Webhooks → Create a new hook** (Create twice):

**Webhook 1: Workshop Alerts**
- **Name:** `notify-workshop-on-booking`
- **Table:** `public.garage_notifications`
- **Events:** `Insert`
- **Type:** `Supabase Edge Functions`
- **Edge Function:** `notify-garage`
- **HTTP Headers:** `x-webhook-secret: <YOUR_WEBHOOK_SECRET>`

**Webhook 2: Customer Alerts**
- **Name:** `notify-customer-on-update`
- **Table:** `public.customer_alerts`
- **Events:** `Insert`
- **Type:** `Supabase Edge Functions`
- **Edge Function:** `notify-garage`
- **HTTP Headers:** `x-webhook-secret: <YOUR_WEBHOOK_SECRET>`

---

### 6.2 Google Cloud Console Setup

1. Open [Google Cloud Console](https://console.cloud.google.com).
2. Go to **APIs & Services → Credentials → OAuth Client IDs**.
3. **Web Application Client:**
   - Name: `Supabase Auth Client`
   - Authorised redirect URI:
     ```text
     https://zlrmcrhwtfbwbxhfmygs.supabase.co/auth/v1/callback
     ```
   - Copy Client ID (`787349507364-b943fq2sf47h2eqa3chiuck7923q7gv7.apps.googleusercontent.com`) into Supabase **Authentication → Providers → Google**.
4. **Android Client (Workshop Console):**
   - Package name: `com.balajiautomobiles.garage` (and `com.garagepro.garagepro_admin`)
   - SHA-1 Fingerprint: `83:99:64:B6:0E:36:1D:AB:E1:92:2A:F5:8D:BC:41:21:0B:20:19:41`
5. **Android Client (Customer App):**
   - Package name: `com.balajiautomobiles.customer` (and `com.garagepro.garagepro`)
   - SHA-1 Fingerprint: `83:99:64:B6:0E:36:1D:AB:E1:92:2A:F5:8D:BC:41:21:0B:20:19:41`

---

### 6.3 Firebase Console (Push Notifications) Setup

1. Open [Firebase Console](https://console.firebase.google.com).
2. Add Android Apps matching the package names above.
3. Download `google-services.json` and place in `Admin/android/app/` and `User/android/app/`.
4. Navigate to **Project Settings → Service Accounts → Firebase Admin SDK**.
5. Click **Generate new private key** (downloads a `.json` file).
6. Paste the entire JSON file content into the Supabase Secret `FCM_SERVICE_ACCOUNT`.

---

## 7. Role-Based Access Control (RBAC) & Team Management

The workshop console enforces role hierarchy across three separate security barriers:
1. **App Router:** Refuses unauthorized navigation routes.
2. **Screen Layer:** UI elements, action buttons, and profit views hide automatically.
3. **PostgreSQL RLS Policies:** The database rejects unauthorized queries at the protocol level.

### Permission Matrix

| Feature / Action | Super Admin | Owner / Admin | Manager | Counter / Store | Accountant | Mechanic |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Platform Partners Directory** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Workshop Settings & Legal** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Staff & Payroll Management**| ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Purchase Rates & Profit %** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Create / Edit Job Cards** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **View Assigned Job Cards** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (Own Only)|
| **Parts Issue & Counter Sales**| ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Billing, Invoicing & Ledgers**| ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| **Punch Own Attendance** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### How to Invite Staff Members
1. Owner opens console → **Settings → User Management → + (Add Staff)**.
2. Enter staff Name, Phone Number, Email, and assign a Role (`Manager`, `Mechanic`, `Storekeeper`, `Accountant`).
3. Set an initial staff password.
4. When the staff member downloads the app and signs in with that email/password, they are linked directly to the workshop under their designated role permissions.

---

## 8. GST Engine & Invoice Templates

The invoicing engine in `Admin/lib/core/tax/gst.dart` strictly adheres to Indian GST compliance standards.

### GST Calculation Logic
- **Intra-State Supply (Customer state == Workshop state):** Automatically splits tax evenly into **CGST** and **SGST** (e.g. 18% total = 9% CGST + 9% SGST).
- **Inter-State Supply (Customer state != Workshop state):** Applies full rate as **IGST** (e.g. 18% IGST).
- **Tax Inclusive vs Exclusive:** Toggleable in settings. Exclusive adds GST to subtotal; Inclusive calculates backward to extract base taxable value without changing customer total.
- **HSN/SAC Codes:** Supported per line item (e.g. `2710` for lubricants, `9987` for automotive maintenance labour).
- **Rounding:** Automatic mathematical round-off to the nearest integer rupee printed on its own line item.

### 6 Premium Invoice Print Templates
Available under **Settings → Invoice Themes & Templates**:
1. **Default (Original):** Clean, standard workshop layout with letterhead.
2. **Default (Two Logos):** Dual branding for workshop + OEM partner (e.g. Bosch / Castrol).
3. **Luxury:** Dark elegant headings, refined typography, and border treatments.
4. **Advanced GST (Tally Style):** Formal accounting format featuring full HSN/SAC rollup summary tables.
5. **Billbook:** Compact classic counter billing format.
6. **Simple:** Minimalist single-sheet format for quick oil and routine service jobs.

---

## 9. Release Artifacts & Client Deliverables

All tested, production-grade release binaries and documentation are ready inside the repository:

### 9.1 Android Application Binaries
Located in `release-apks/`:
- **Admin Workshop Console APK:** `balaji-admin-1.0.10-arm64.apk`
- **Customer Mobile App APK:** `balaji-automobiles-1.0.4-arm64.apk`

### 9.2 Training & Walkthrough Video Guides
Located in `qa-evidence/video/`:
- `admin-hindi-guide.mp4`: Complete 4-minute 35-second walkthrough of all 22 workshop console features with clear English visual cues and Hinglish voice-over.
- `user-hindi-guide.mp4`: 1-minute 30-second walkthrough for customer appointment booking, live repair tracking, and WhatsApp bill inspection.
- `narration-hinglish.md`: Complete spoken word transcript for localization.

### 9.3 Client Handover Interactive Portal
- **HTML File:** `docs/handover.html` (and `Website/public/handover.html`)
- Can be opened directly in any browser for interactive viewing, search, and 1-click printing to PDF.

---

## 10. Troubleshooting, Health Checks & Maintenance

### Quick Verification SQL Script
Run in the Supabase SQL editor to verify that all systems are operational:
```sql
-- 1. Check Super Admin status
select u.email, u.email_confirmed_at is not null as confirmed, p.role
  from auth.users u
  join public.profiles p on p.id = u.id
 where lower(u.email) = 'balajiautomobiles088@gmail.com';

-- 2. Verify Workshop Registration & Verification
select name, phone, city, pin, lat, lng, listed, verified
  from public.garages
 where lower(email) = 'balajiautomobiles088@gmail.com';

-- 3. Check Active Registered Push Notification Devices
select count(*) as active_workshop_phones from public.garage_devices;
select count(*) as active_customer_phones from public.customer_devices;
```

### Common Questions & Solutions

#### Q1: A customer says they cannot see Balaji Automobiles when searching in the customer app.
- **Cause:** The workshop has not set its GPS coordinate, or `listed` is false.
- **Fix:** In the Admin Console, go to **Settings → Workshop Details → Use Current Location → Save**. Alternatively, in Supabase SQL run:
  ```sql
  update public.garages set listed = true, verified = true where lower(email) = 'balajiautomobiles088@gmail.com';
  ```

#### Q2: Bookings arrive, but the counter phone does not ring when the app is closed.
- **Fix Checklist:**
  1. Check Supabase Edge Function logs (`notify-garage`) for any 403 errors (indicates `WEBHOOK_SECRET` mismatch).
  2. Confirm `FCM_SERVICE_ACCOUNT` is set in Supabase Secrets.
  3. Ensure Android notification permission is allowed on the phone.
  4. On Xiaomi/Redmi/Oppo devices, ensure the app has "Autostart" and "Unrestricted Battery" permissions toggled on.

#### Q3: How does the customer see their bill without installing the app?
- **Workflow:** When the workshop opens or updates a job card, tap **Share on WhatsApp**. The app generates a secure link: `https://balajiautomobiles.in/j/<token>`. The customer clicks the link in WhatsApp and views their live invoice immediately in their web browser.

---
**Handover Completed & Certified for Balaji Automobiles.**  
*System Lead & Freelance Engineering Team*
