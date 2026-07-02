# MKG security and HIPAA readiness

The repository contains a technical foundation; it does not by itself make MKG HIPAA compliant.

Before enabling real PHI:

1. Upgrade Vercel to a plan eligible for a BAA/HIPAA add-on and execute the agreement.
2. Create a hosted Supabase Team-or-higher organization, execute its BAA, enable the HIPAA add-on, and mark the project High Compliance.
3. Enable Supabase Point-in-Time Recovery, SSL enforcement, network restrictions, MFA enforcement, and Postgres connection logging.
4. Apply `supabase/migrations/001_secure_foundation.sql` in a non-production test project first, review every RLS policy, then promote it through a controlled migration.
5. Configure only the publishable browser key in Vercel. Never expose a service-role key in `VITE_*` variables or client code.
6. Keep document buckets private. Validate office membership and task access server-side before issuing signed URLs.
7. Complete organizational risk analysis, workforce training, incident response, breach notification, retention, backup, disaster recovery, and vendor-management procedures.
8. Use synthetic data until an authorized security/compliance review approves production.

The client deliberately remains in demo mode when Supabase environment variables are absent.

