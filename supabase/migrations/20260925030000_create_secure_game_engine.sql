alter table public.rooms drop constraint rooms_status_supported;
alter table public.rooms add constraint rooms_status_supported
  check (status in ('waiting', 'in_game', 'closed'));

create table public.words (
  id bigint generated always as identity primary key,
  category_id bigint not null references public.categories (id) on delete restrict,
  word_vi text not null,
  word_en text not null,
  difficulty smallint not null default 1 check (difficulty between 1 and 3),
  is_active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  constraint words_vi_not_blank check (btrim(word_vi) <> ''),
  constraint words_en_not_blank check (btrim(word_en) <> ''),
  constraint words_category_vi_unique unique (category_id, word_vi),
  constraint words_category_en_unique unique (category_id, word_en)
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete restrict,
  round_number integer not null check (round_number >= 1),
  status text not null,
  category_id bigint not null references public.categories (id) on delete restrict,
  keyword_id bigint not null references public.words (id) on delete restrict,
  phase_started_at timestamptz not null,
  phase_ends_at timestamptz,
  revision bigint not null default 1 check (revision >= 1),
  started_by uuid not null references public.profiles (id) on delete restrict,
  start_request_id uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint games_status_supported check (
    status in ('role_reveal', 'clue', 'discussion', 'voting', 'vote_result', 'final_guess', 'result')
  ),
  constraint games_phase_window check (phase_ends_at is null or phase_ends_at >= phase_started_at),
  constraint games_round_unique unique (room_id, round_number),
  constraint games_start_idempotency unique (started_by, start_request_id)
);

create unique index games_one_active_per_room on public.games (room_id)
where status <> 'result';

create table public.game_players (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games (id) on delete restrict,
  player_id uuid not null references public.profiles (id) on delete restrict,
  role text not null check (role in ('normal', 'impostor')),
  turn_order integer not null check (turn_order >= 1),
  created_at timestamptz not null default statement_timestamp(),
  constraint game_players_player_unique unique (game_id, player_id),
  constraint game_players_turn_unique unique (game_id, turn_order)
);

alter table public.words enable row level security;
alter table public.words force row level security;
alter table public.games enable row level security;
alter table public.games force row level security;
alter table public.game_players enable row level security;
alter table public.game_players force row level security;

revoke all on table public.words, public.games, public.game_players
  from public, anon, authenticated;
revoke all on sequence public.words_id_seq, public.game_players_id_seq
  from public, anon, authenticated;

create trigger games_set_updated_at before update on public.games
for each row execute function public.set_updated_at();

insert into public.words (category_id, word_vi, word_en, difficulty)
select c.id, seed.word_vi, seed.word_en, seed.difficulty
from public.categories c
join (values
 ('food','Phở','Pho',1),('food','Bánh mì','Banh mi',1),('food','Dưa hấu','Watermelon',1),('food','Kem','Ice cream',1),('food','Pizza','Pizza',1),('food','Cơm rang','Fried rice',1),('food','Sushi','Sushi',1),('food','Bánh chưng','Sticky rice cake',2),('food','Mì Ý','Pasta',1),('food','Sô-cô-la','Chocolate',1),
 ('animals','Con mèo','Cat',1),('animals','Con chó','Dog',1),('animals','Con voi','Elephant',1),('animals','Hươu cao cổ','Giraffe',1),('animals','Chim cánh cụt','Penguin',1),('animals','Cá heo','Dolphin',1),('animals','Con hổ','Tiger',1),('animals','Con thỏ','Rabbit',1),('animals','Con rùa','Turtle',1),('animals','Con công','Peacock',2),
 ('places','Trường học','School',1),('places','Bệnh viện','Hospital',1),('places','Sân bay','Airport',1),('places','Bãi biển','Beach',1),('places','Thư viện','Library',1),('places','Siêu thị','Supermarket',1),('places','Công viên','Park',1),('places','Rạp chiếu phim','Cinema',1),('places','Nhà ga','Train station',1),('places','Bảo tàng','Museum',2),
 ('objects','Cái ô','Umbrella',1),('objects','Điện thoại','Phone',1),('objects','Bàn chải','Toothbrush',1),('objects','Ba lô','Backpack',1),('objects','Đồng hồ','Watch',1),('objects','Kéo','Scissors',1),('objects','Gương','Mirror',1),('objects','Đèn pin','Flashlight',1),('objects','Máy ảnh','Camera',1),('objects','Ấm nước','Kettle',2),
 ('jobs','Bác sĩ','Doctor',1),('jobs','Giáo viên','Teacher',1),('jobs','Đầu bếp','Chef',1),('jobs','Phi công','Pilot',1),('jobs','Lính cứu hỏa','Firefighter',1),('jobs','Kiến trúc sư','Architect',2),('jobs','Ca sĩ','Singer',1),('jobs','Nông dân','Farmer',1),('jobs','Thợ cắt tóc','Hairdresser',1),('jobs','Lập trình viên','Programmer',1),
 ('sports','Bóng đá','Football',1),('sports','Bóng rổ','Basketball',1),('sports','Bơi lội','Swimming',1),('sports','Cầu lông','Badminton',1),('sports','Quần vợt','Tennis',1),('sports','Bóng chuyền','Volleyball',1),('sports','Cờ vua','Chess',1),('sports','Đạp xe','Cycling',1),('sports','Chạy bộ','Running',1),('sports','Bắn cung','Archery',2),
 ('entertainment','Karaoke','Karaoke',1),('entertainment','Phim hoạt hình','Cartoon',1),('entertainment','Ảo thuật','Magic show',1),('entertainment','Hòa nhạc','Concert',1),('entertainment','Trò chơi điện tử','Video game',1),('entertainment','Xiếc','Circus',1),('entertainment','Nhảy múa','Dancing',1),('entertainment','Đọc truyện','Reading stories',1),('entertainment','Chụp ảnh','Photography',1),('entertainment','Cắm trại','Camping',1),
 ('vietnam','Áo dài','Ao dai',1),('vietnam','Nón lá','Conical hat',1),('vietnam','Vịnh Hạ Long','Ha Long Bay',1),('vietnam','Chợ Bến Thành','Ben Thanh Market',1),('vietnam','Cầu Rồng','Dragon Bridge',1),('vietnam','Hoa sen','Lotus',1),('vietnam','Xe máy','Motorbike',1),('vietnam','Cà phê sữa đá','Vietnamese iced coffee',1),('vietnam','Múa rối nước','Water puppetry',2),('vietnam','Tết','Lunar New Year',1),
 ('friends','Bạn thân','Best friend',1),('friends','Nhóm chat','Group chat',1),('friends','Sinh nhật','Birthday',1),('friends','Chuyến đi','Road trip',1),('friends','Ảnh kỷ niệm','Memory photo',1),('friends','Lời hứa','Promise',1),('friends','Bí mật','Secret',1),('friends','Trò đùa','Joke',1),('friends','Cuộc gọi','Phone call',1),('friends','Buổi họp lớp','Reunion',2),
 ('relationships','Gia đình','Family',1),('relationships','Đồng nghiệp','Colleague',1),('relationships','Hàng xóm','Neighbor',1),('relationships','Anh chị em','Sibling',1),('relationships','Đồng đội','Teammate',1),('relationships','Người yêu','Partner',1),('relationships','Thầy trò','Teacher and student',1),('relationships','Đối thủ','Rival',1),('relationships','Khách hàng','Customer',1),('relationships','Bạn cùng phòng','Roommate',1)
) seed(category_key, word_vi, word_en, difficulty) on seed.category_key = c.key;

create function private.game_snapshot(p_game_id uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'game_id', g.id,
    'room_id', g.room_id,
    'round_number', g.round_number,
    'status', g.status,
    'phase_started_at', g.phase_started_at,
    'phase_ends_at', g.phase_ends_at,
    'revision', g.revision,
    'participants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'player_id', gp.player_id,
        'username', p.username,
        'avatar_id', p.avatar_id
      ) order by p.username, gp.player_id)
      from public.game_players gp
      join public.profiles p on p.id = gp.player_id
      where gp.game_id = g.id
    ), '[]'::jsonb)
  ) from public.games g where g.id = p_game_id;
$$;
revoke all on function private.game_snapshot(uuid) from public, anon, authenticated;

create function public.get_current_game()
returns jsonb language plpgsql security definer stable set search_path = '' as $$
declare v_user_id uuid := auth.uid(); v_game_id uuid;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  select gp.game_id into v_game_id from public.game_players gp
  join public.games g on g.id = gp.game_id
  where gp.player_id = v_user_id and g.status <> 'result'
  order by g.created_at desc limit 1;
  if v_game_id is null then return null; end if;
  return private.game_snapshot(v_game_id);
end;
$$;

create function public.get_my_game_secret()
returns jsonb language plpgsql security definer stable set search_path = '' as $$
declare v_user_id uuid := auth.uid(); v_role text; v_word_vi text; v_word_en text;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  select gp.role,
    case when gp.role='normal' then w.word_vi end,
    case when gp.role='normal' then w.word_en end
  into v_role, v_word_vi, v_word_en
  from public.game_players gp join public.games g on g.id=gp.game_id
  join public.words w on w.id=g.keyword_id
  where gp.player_id=v_user_id and g.status <> 'result'
  order by g.created_at desc limit 1;
  if v_role is null then raise exception 'not_game_participant' using errcode='P0001'; end if;
  return jsonb_build_object('role',v_role,'word_vi',v_word_vi,'word_en',v_word_en);
end;
$$;

create function public.start_game(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid(); v_room public.rooms; v_game_id uuid;
  v_category_id bigint; v_keyword_id bigint; v_count integer; v_round integer;
  v_index integer := 0; v_player_id uuid;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  if p_request_id is null then raise exception 'invalid_start_request' using errcode='P0001'; end if;
  perform private.assert_profile(v_user_id);
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 1));

  select g.id into v_game_id from public.games g
  where g.started_by=v_user_id and g.start_request_id=p_request_id;
  if v_game_id is not null then return private.game_snapshot(v_game_id); end if;

  select r.* into v_room from public.room_players rp
  join public.rooms r on r.id=rp.room_id
  where rp.player_id=v_user_id and rp.left_at is null for update of r;
  if not found then raise exception 'not_room_member' using errcode='P0001'; end if;
  if v_room.host_id <> v_user_id then raise exception 'not_host' using errcode='P0001'; end if;
  if v_room.status = 'in_game' then raise exception 'game_already_started' using errcode='P0001'; end if;
  if v_room.status <> 'waiting' then raise exception 'room_closed' using errcode='P0001'; end if;
  if exists(select 1 from public.games g where g.room_id=v_room.id and g.status<>'result') then
    raise exception 'game_already_started' using errcode='P0001';
  end if;

  select count(*)::integer into v_count from public.room_players rp
  where rp.room_id=v_room.id and rp.left_at is null;
  if v_count < 3 then raise exception 'not_enough_players' using errcode='P0001'; end if;
  if v_count > v_room.max_players then raise exception 'invalid_game_settings' using errcode='P0001'; end if;
  if exists(select 1 from public.room_players rp where rp.room_id=v_room.id and rp.left_at is null and rp.player_id<>v_user_id and not rp.is_ready) then
    raise exception 'players_not_ready' using errcode='P0001';
  end if;
  if (v_count between 3 and 6 and v_room.impostor_count<>1)
    or (v_count between 7 and 10 and v_room.impostor_count not in (1,2)) then
    raise exception 'invalid_game_settings' using errcode='P0001';
  end if;

  if v_room.category_id is null then
    select c.id into v_category_id from public.categories c
    where c.is_active and exists(select 1 from public.words w where w.category_id=c.id and w.is_active)
    order by encode(extensions.gen_random_bytes(16),'hex') limit 1;
  else
    select c.id into v_category_id from public.categories c
    where c.id=v_room.category_id and c.is_active;
  end if;
  if v_category_id is null then raise exception 'invalid_game_settings' using errcode='P0001'; end if;
  select w.id into v_keyword_id from public.words w
  where w.category_id=v_category_id and w.is_active
  order by encode(extensions.gen_random_bytes(16),'hex') limit 1;
  if v_keyword_id is null then raise exception 'no_eligible_words' using errcode='P0001'; end if;

  select coalesce(max(g.round_number),0)+1 into v_round from public.games g where g.room_id=v_room.id;
  insert into public.games(room_id,round_number,status,category_id,keyword_id,
    phase_started_at,phase_ends_at,started_by,start_request_id)
  values(v_room.id,v_round,'role_reveal',v_category_id,v_keyword_id,
    statement_timestamp(),statement_timestamp()+interval '15 seconds',v_user_id,p_request_id)
  returning id into v_game_id;

  for v_player_id in select rp.player_id from public.room_players rp
    where rp.room_id=v_room.id and rp.left_at is null
    order by encode(extensions.gen_random_bytes(16),'hex') loop
    v_index := v_index + 1;
    insert into public.game_players(game_id,player_id,role,turn_order)
    values(v_game_id,v_player_id,'normal',v_index);
  end loop;
  update public.game_players set role='impostor' where id in (
    select gp.id from public.game_players gp where gp.game_id=v_game_id
    order by encode(extensions.gen_random_bytes(16),'hex') limit v_room.impostor_count
  );
  update public.rooms set status='in_game', revision=revision+1 where id=v_room.id;
  return private.game_snapshot(v_game_id);
end;
$$;

create or replace function public.get_current_room()
returns jsonb language plpgsql security definer stable set search_path = '' as $$
declare v_user_id uuid := auth.uid(); v_room_id uuid;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  select rp.room_id into v_room_id from public.room_players rp join public.rooms r on r.id=rp.room_id
  where rp.player_id=v_user_id and rp.left_at is null and r.status in ('waiting','in_game');
  if v_room_id is null then return null; end if;
  return private.room_snapshot(v_room_id);
end;
$$;

create or replace function public.leave_room()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid := auth.uid(); v_room public.rooms; v_next_host uuid;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text,0));
  select r.* into v_room from public.room_players rp join public.rooms r on r.id=rp.room_id
  where rp.player_id=v_user_id and rp.left_at is null for update of r;
  if not found then return null; end if;
  if v_room.status='in_game' then raise exception 'room_in_game' using errcode='P0001'; end if;
  update public.room_players set left_at=statement_timestamp()
  where room_id=v_room.id and player_id=v_user_id and left_at is null;
  if v_room.host_id=v_user_id then
    select rp.player_id into v_next_host from public.room_players rp
    where rp.room_id=v_room.id and rp.left_at is null order by rp.joined_at,rp.seat,rp.player_id limit 1;
    if v_next_host is null then
      update public.rooms set status='closed',host_id=null where id=v_room.id;
    else
      update public.rooms set host_id=v_next_host where id=v_room.id;
    end if;
  end if;
  return null;
end;
$$;

revoke all on function public.start_game(uuid), public.get_current_game(), public.get_my_game_secret()
  from public, anon, authenticated;
grant execute on function public.start_game(uuid), public.get_current_game(), public.get_my_game_secret()
  to authenticated;
