# Chess Arena — Online Multiplayer Plan (v2)

v1 is offline-first (Hive + bots). This doc is the plug-in plan for online
play: **try online first, fall back to a bot** when nobody is around —
exactly the launch strategy for a new game with no audience yet.

## Code seam (already in v1)

`lib/features/matchmaking/opponent_source.dart` defines:

```dart
abstract class OpponentSource {
  Future<BotProfile> findOpponent({required PlayerProfile player});
}
```

v2 adds `SupabaseMatchmakingSource implements OpponentSource` (+ a
`RemoteGameController` for live games). The UI does not change: the
searching screen already handles delays, cancel, ELO preview and fallback.

Match flow v2:

```
startSearch()
  → insert into match_queue (or upsert)
  → listen on realtime channel `match:<user_id>` (8–10s timeout)
  → MATCHED   → open live game (white/black assigned by server)
  → TIMEOUT   → delete queue row → OfflineBotSource (bot with flag/avatar)
```

## SQL schema (run in Supabase SQL editor)

```sql
-- Public rating profile (one row per auth user).
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Player',
  rating int not null default 1000,
  games int not null default 0,
  wins int not null default 0,
  losses int not null default 0,
  draws int not null default 0,
  updated_at timestamptz not null default now()
);

-- Matchmaking queue: one row per searching player.
create table if not exists public.match_queue (
  user_id uuid primary key references auth.users(id) on delete cascade,
  rating int not null,
  inserted_at timestamptz not null default now()
);

-- Matches.
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  white_id uuid references auth.users(id),
  black_id uuid references auth.users(id),
  status text not null default 'live', -- live | white_wins | black_wins | draw | aborted
  fen text not null default 'startpos',
  turn text not null default 'w',
  winner_points_white int not null default 0,
  winner_points_black int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Move log (also powers rematch review + anti-cheat later).
create table if not exists public.match_moves (
  id bigserial primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  ply int not null,
  uci text not null,
  fen_after text not null,
  created_at timestamptz not null default now()
);
create index if not exists match_moves_match_idx on public.match_moves(match_id);

-- Auto-create a profile on signup.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', 'Player'));
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

## RLS sketch

```sql
alter table public.profiles enable row level security;
alter table public.match_queue enable row level security;
alter table public.matches enable row level security;
alter table public.match_moves enable row level security;

-- Profiles: readable by all, writable by owner.
create policy "profiles read all" on public.profiles
  for select using (true);
create policy "profiles update own" on public.profiles
  for update using (auth.uid() = id);

-- Queue: owner manages own row; matching reads others.
create policy "queue own all" on public.match_queue
  for all using (auth.uid() = user_id);
create policy "queue read all" on public.match_queue
  for select using (true);

-- Matches/moves: readable by participants (Edge Function writes results).
create policy "matches read own" on public.matches
  for select using (auth.uid() = white_id or auth.uid() = black_id);
create policy "moves read own" on public.match_moves
  for select using (
    exists (select 1 from public.matches m
      where m.id = match_id
      and (auth.uid() = m.white_id or auth.uid() = m.black_id))
  );
```

## Match function (pairing within ±250 ELO)

Simplest fair pairing without a server: the *joiner* claims the oldest
compatible waiter in one transaction (Supabase RPC):

```sql
create or replace function public.claim_match(my_rating int)
returns uuid language plpgsql security definer as $$
declare
  opp uuid;
  mid uuid;
begin
  select user_id into opp from public.match_queue
    where user_id <> auth.uid()
      and abs(rating - my_rating) <= 250
    order by inserted_at asc
    limit 1
    for update skip locked;
  if opp is null then
    return null; -- nobody compatible: keep waiting (caller times out → bot)
  end if;
  delete from public.match_queue where user_id in (opp, auth.uid());
  -- Random colours.
  if random() < 0.5 then
    insert into public.matches (white_id, black_id)
      values (auth.uid(), opp) returning id into mid;
  else
    insert into public.matches (white_id, black_id)
      values (opp, auth.uid()) returning id into mid;
  end if;
  return mid;
end $$;
```

Client loop: `upsert queue` → poll `claim_match()` every 1s → on UUID,
subscribe to `matches:id=eq:<uuid>` + a `match_moves` channel → play.

## Live game transport (Supabase Realtime)

* One broadcast/presence channel per match: `game:<match_id>`.
* Moves: insert into `match_moves` (RLS: participant-only write policy to
  add) → both clients receive the postgres-changes event → apply via the
  *same* `genetom_chess_engine` legality check (never trust the wire).
* Chat: reuse the existing chat UI; transport = broadcast on `game:<id>`.
* Timers/disconnects: presence + `updated_at` heartbeat; abort after 60s.

## ELO settlement

Reuse `EloService` (same K-factors) on both clients for instant UI, then an
Edge Function (or a `SECURITY DEFINER` RPC at game end) writes authoritative
`profiles.rating` + `matches.status`. Client values are optimistic only.

## Packages to add in v2

```yaml
supabase_flutter: ^2.x
```

No v1 code needs rewriting: add the source, the live controller, and keys.
