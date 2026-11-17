-- Phase 0 — Foundations.
--
-- No game schema yet. This migration only establishes the security default
-- every later migration builds on, and one RPC to prove the whole pipe
-- (Flutter -> supabase_flutter -> hosted Postgres -> auth) works end to end.

-- Anonymous *users* still get the `authenticated` Postgres role (see plan:
-- Architecture > Decisions worth recording). This revoke removes the
-- unauthenticated `anon` role's default table access — belt-and-braces
-- ahead of any table existing, so nothing is ever grandfathered in.
revoke all on all tables in schema public from anon;

-- The one RPC every client calls to measure its clock offset against the
-- server (see lib/game/clock.dart). `security invoker` deliberately —
-- this never needs to bypass RLS, and nothing here should set the
-- precedent of reaching for `security definer` when it isn't needed.
create or replace function public.server_now()
returns timestamptz
language sql
security invoker
stable
as $$
  select now();
$$;

grant execute on function public.server_now() to authenticated;
