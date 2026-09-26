create index game_players_player_game_idx on public.game_players(player_id,game_id);
create index games_result_history_idx on public.games(finished_at desc,id desc)where status='result';
alter table public.profiles add constraint profiles_wins_consistent check(games_won<=games_played and normal_wins+impostor_wins=games_won),
add constraint profiles_correct_votes_consistent check(correct_votes<=games_played);

create function private.profile_snapshot(p_user uuid)returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('id',p.id,'username',p.username,'avatar_id',p.avatar_id,'coins',p.coins,'xp',p.xp,'level',p.level,
'games_played',p.games_played,'games_won',p.games_won,'normal_wins',p.normal_wins,'impostor_wins',p.impostor_wins,'correct_votes',p.correct_votes,
'created_at',p.created_at,'updated_at',p.updated_at)from public.profiles p where p.id=p_user;$$;
revoke all on function private.profile_snapshot(uuid)from public,anon,authenticated;

create function public.get_my_profile()returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();begin if v_user is null then raise exception'authentication_required'using errcode='P0001';end if;
return private.profile_snapshot(v_user);end;$$;

create function public.update_my_profile(p_username text,p_avatar_id text)returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_name text:=regexp_replace(btrim(p_username),'[[:space:]]+',' ','g');v_current public.profiles;
begin if v_user is null then raise exception'authentication_required'using errcode='P0001';end if;
if v_name is null or char_length(v_name)<2 or char_length(v_name)>20 or v_name~'[[:cntrl:]]'then raise exception'invalid_username'using errcode='P0001';end if;
if p_avatar_id is null or p_avatar_id<>all(array['avatar_01','avatar_02','avatar_03','avatar_04','avatar_05','avatar_06','avatar_07','avatar_08','avatar_09','avatar_10','avatar_11','avatar_12']::text[])then raise exception'invalid_avatar'using errcode='P0001';end if;
select*into strict v_current from public.profiles where id=v_user for update;
if v_current.username<>v_name or v_current.avatar_id<>p_avatar_id then update public.profiles set username=v_name,avatar_id=p_avatar_id where id=v_user;end if;
return private.profile_snapshot(v_user);end;$$;

create function public.get_my_game_history(p_limit integer default 20,p_before_finished_at timestamptz default null,p_before_game_id uuid default null)
returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_items jsonb;v_next_time timestamptz;v_next_id uuid;
begin if v_user is null then raise exception'authentication_required'using errcode='P0001';end if;
if p_limit is null or p_limit<1 or p_limit>50 then raise exception'invalid_history_limit'using errcode='P0001';end if;
if (p_before_finished_at is null)<>(p_before_game_id is null)then raise exception'invalid_history_cursor'using errcode='P0001';end if;
with page as(select g.id,g.round_number,g.finished_at,g.winner_team,g.result_reason,gp.role,w.word_vi,w.word_en,c.name_vi category_vi,c.name_en category_en,
gr.xp_delta,gr.coins_delta,(gp.role=g.winner_team) did_win,(select count(*)::integer from public.game_players x where x.game_id=g.id)player_count
from public.game_players gp join public.games g on g.id=gp.game_id join public.words w on w.id=g.keyword_id join public.categories c on c.id=g.category_id
join public.game_rewards gr on gr.game_id=g.id and gr.player_id=gp.player_id where gp.player_id=v_user and g.status='result'
and(p_before_finished_at is null or(g.finished_at,g.id)<(p_before_finished_at,p_before_game_id))order by g.finished_at desc,g.id desc limit p_limit),
packed as(select jsonb_agg(jsonb_build_object('game_id',id,'round_number',round_number,'finished_at',finished_at,'winner_team',winner_team,'result_reason',result_reason,
'caller_role',role,'did_win',did_win,'keyword_vi',word_vi,'keyword_en',word_en,'category_vi',category_vi,'category_en',category_en,'xp_gained',xp_delta,'coins_gained',coins_delta,'player_count',player_count)
order by finished_at desc,id desc)items,(array_agg(finished_at order by finished_at desc,id desc))[count(*)]last_time,(array_agg(id order by finished_at desc,id desc))[count(*)]last_id,count(*)n from page)
select coalesce(items,'[]'::jsonb),case when n=p_limit then last_time end,case when n=p_limit then last_id end into v_items,v_next_time,v_next_id from packed;
return jsonb_build_object('items',v_items,'next_finished_at',v_next_time,'next_game_id',v_next_id);end;$$;

revoke all on function public.get_my_profile(),public.update_my_profile(text,text),public.get_my_game_history(integer,timestamptz,uuid)from public,anon,authenticated;
grant execute on function public.get_my_profile(),public.update_my_profile(text,text),public.get_my_game_history(integer,timestamptz,uuid)to authenticated;
