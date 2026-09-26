create table public.ad_rewards(
  id uuid primary key default extensions.gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check(char_length(provider) between 2 and 32),
  provider_event_id text not null check(char_length(provider_event_id) between 8 and 200),
  reward_type text not null default 'rewarded_ad' check(reward_type='rewarded_ad'),
  coins_delta integer not null default 50 check(coins_delta=50),
  status text not null check(status in('granted','daily_limit_reached')),
  created_at timestamptz not null default clock_timestamp(),
  granted_at timestamptz,
  unique(provider,provider_event_id),
  check((status='granted')=(granted_at is not null))
);
create index ad_rewards_player_granted_idx on public.ad_rewards(player_id,granted_at desc)where status='granted';
alter table public.ad_rewards enable row level security;
alter table public.ad_rewards force row level security;
revoke all on public.ad_rewards from public,anon,authenticated;

create table public.monetization_events(
  id uuid primary key default extensions.gen_random_uuid(),
  provider text not null check(char_length(provider) between 2 and 32),
  provider_event_id text not null check(char_length(provider_event_id) between 8 and 200),
  player_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check(event_type in('remove_ads_active','remove_ads_inactive')),
  source_transaction_id text not null check(char_length(source_transaction_id) between 3 and 200),
  provider_occurred_at timestamptz not null,
  received_at timestamptz not null default clock_timestamp(),
  unique(provider,provider_event_id)
);
create index monetization_events_player_idx on public.monetization_events(player_id,provider_occurred_at desc);
alter table public.monetization_events enable row level security;
alter table public.monetization_events force row level security;
revoke all on public.monetization_events from public,anon,authenticated;

create table public.player_entitlements(
  player_id uuid not null references public.profiles(id) on delete cascade,
  entitlement_type text not null check(entitlement_type='remove_ads'),
  source text not null check(char_length(source) between 2 and 32),
  source_transaction_id text not null check(char_length(source_transaction_id) between 3 and 200),
  active boolean not null,
  provider_occurred_at timestamptz not null,
  granted_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  primary key(player_id,entitlement_type),
  unique(source,source_transaction_id),
  check(active=(granted_at is not null))
);
alter table public.player_entitlements enable row level security;
alter table public.player_entitlements force row level security;
revoke all on public.player_entitlements from public,anon,authenticated;

create function public.get_my_monetization_state()returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_used integer;v_remove_ads boolean;
begin
  if v_user is null then raise exception'authentication_required'using errcode='P0001';end if;
  select count(*)::integer into v_used from public.ad_rewards where player_id=v_user and status='granted'
    and granted_at>=date_trunc('day',clock_timestamp() at time zone'UTC')at time zone'UTC'
    and granted_at<(date_trunc('day',clock_timestamp() at time zone'UTC')+interval'1 day')at time zone'UTC';
  select coalesce(bool_or(active),false)into v_remove_ads from public.player_entitlements where player_id=v_user and entitlement_type='remove_ads';
  return jsonb_build_object('remove_ads',v_remove_ads,'rewarded_used_today',v_used,'rewarded_remaining_today',greatest(0,3-v_used),
    'can_watch_rewarded_ad',v_used<3,'day_resets_at',(date_trunc('day',clock_timestamp()at time zone'UTC')+interval'1 day')at time zone'UTC');
end;$$;

-- Trusted verification boundary. Only the service role/provider webhook adapter
-- may call this after verifying provider evidence; mobile clients cannot.
create function public.process_verified_ad_reward(p_player_id uuid,p_provider text,p_provider_event_id text)returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_existing public.ad_rewards;v_used integer;v_row public.ad_rewards;
begin
  if auth.role()<>'service_role' then raise exception'verification_required'using errcode='P0001';end if;
  select*into v_existing from public.ad_rewards where provider=p_provider and provider_event_id=p_provider_event_id;
  if found then return jsonb_build_object('status',v_existing.status,'coins_delta',case when v_existing.status='granted'then 50 else 0 end);end if;
  perform 1 from public.profiles where id=p_player_id for update;
  if not found then raise exception'profile_not_found'using errcode='P0001';end if;
  select count(*)::integer into v_used from public.ad_rewards where player_id=p_player_id and status='granted'
    and granted_at>=date_trunc('day',clock_timestamp()at time zone'UTC')at time zone'UTC'
    and granted_at<(date_trunc('day',clock_timestamp()at time zone'UTC')+interval'1 day')at time zone'UTC';
  if v_used>=3 then
    insert into public.ad_rewards(player_id,provider,provider_event_id,status)values(p_player_id,p_provider,p_provider_event_id,'daily_limit_reached')returning*into v_row;
    return jsonb_build_object('status',v_row.status,'coins_delta',0);
  end if;
  insert into public.ad_rewards(player_id,provider,provider_event_id,status,granted_at)
    values(p_player_id,p_provider,p_provider_event_id,'granted',clock_timestamp())returning*into v_row;
  update public.profiles set coins=coins+50 where id=p_player_id;
  return jsonb_build_object('status','granted','coins_delta',50);
exception when unique_violation then
  select*into v_existing from public.ad_rewards where provider=p_provider and provider_event_id=p_provider_event_id;
  return jsonb_build_object('status',v_existing.status,'coins_delta',case when v_existing.status='granted'then 50 else 0 end);
end;$$;

create function public.process_verified_entitlement_event(p_player_id uuid,p_provider text,p_provider_event_id text,p_source_transaction_id text,p_active boolean,p_provider_occurred_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_current public.player_entitlements;v_type text:=case when p_active then'remove_ads_active'else'remove_ads_inactive'end;
begin
  if auth.role()<>'service_role' then raise exception'verification_required'using errcode='P0001';end if;
  insert into public.monetization_events(provider,provider_event_id,player_id,event_type,source_transaction_id,provider_occurred_at)
    values(p_provider,p_provider_event_id,p_player_id,v_type,p_source_transaction_id,p_provider_occurred_at)
    on conflict(provider,provider_event_id)do nothing;
  if not found then select*into v_current from public.player_entitlements where player_id=p_player_id and entitlement_type='remove_ads';
    return jsonb_build_object('active',coalesce(v_current.active,false),'duplicate',true);end if;
  insert into public.player_entitlements(player_id,entitlement_type,source,source_transaction_id,active,provider_occurred_at,granted_at)
    values(p_player_id,'remove_ads',p_provider,p_source_transaction_id,p_active,p_provider_occurred_at,case when p_active then clock_timestamp()end)
  on conflict(player_id,entitlement_type)do update set source=excluded.source,source_transaction_id=excluded.source_transaction_id,
    active=excluded.active,provider_occurred_at=excluded.provider_occurred_at,granted_at=case when excluded.active then coalesce(public.player_entitlements.granted_at,clock_timestamp())end,
    updated_at=clock_timestamp() where excluded.provider_occurred_at>=public.player_entitlements.provider_occurred_at;
  select*into v_current from public.player_entitlements where player_id=p_player_id and entitlement_type='remove_ads';
  return jsonb_build_object('active',v_current.active,'duplicate',false);
end;$$;

revoke all on function public.get_my_monetization_state(),public.process_verified_ad_reward(uuid,text,text),public.process_verified_entitlement_event(uuid,text,text,text,boolean,timestamptz)from public,anon,authenticated;
grant execute on function public.get_my_monetization_state()to authenticated;
grant execute on function public.process_verified_ad_reward(uuid,text,text),public.process_verified_entitlement_event(uuid,text,text,text,boolean,timestamptz)to service_role;
