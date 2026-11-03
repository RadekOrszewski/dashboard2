-- Uruchom w Supabase: SQL Editor. Plany są dostępne wyłącznie przez funkcje RPC
-- (po znajomości losowego UUID); tabela nie jest bezpośrednio czytelna dla anon.

create table if not exists public.plans (
  id uuid primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.plans enable row level security; -- brak polityk = brak dostępu bezpośredniego

create or replace function public.get_plan(p_id uuid)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object('data', data, 'updated_at', updated_at) from plans where id = p_id;
$$;

create or replace function public.upsert_plan(p_id uuid, p_data jsonb)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare ts timestamptz := clock_timestamp();
begin
  if pg_column_size(p_data) > 500000 then raise exception 'plan too large'; end if;
  insert into plans(id, data, updated_at) values (p_id, p_data, ts)
  on conflict (id) do update set data = excluded.data, updated_at = excluded.updated_at;
  return ts;
end $$;

revoke all on function public.get_plan(uuid), public.upsert_plan(uuid, jsonb) from public;
grant execute on function public.get_plan(uuid), public.upsert_plan(uuid, jsonb) to anon;
