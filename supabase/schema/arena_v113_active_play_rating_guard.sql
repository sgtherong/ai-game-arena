create or replace function arena_internal.start_play(p_version uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();x uuid;begin
if u is null or not exists(select 1 from public.profiles where id=u and not suspended) then raise exception 'Active account required';end if;
perform 1 from public.games g join public.versions v on v.id=g.active and v.game_id=g.id where v.id=p_version and v.status='approved' and v.kind in ('demo','zip') and not g.paused and g.owner is distinct from u for share of g;
if not found then raise exception 'Published playable game required; creators cannot record their own game';end if;
insert into public.plays(user_id,version_id) values(u,p_version) returning id into x;return x;end$$;
create or replace function arena_internal.rate_game(p_version uuid,p_stars integer,p_recommend boolean,p_review text) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();begin
if u is null or not exists(select 1 from public.profiles where id=u and not suspended) then raise exception 'Active account required';end if;
if p_stars is null or p_stars not between 1 and 5 or p_recommend is null or length(coalesce(p_review,''))>500 then raise exception 'Invalid rating';end if;
perform 1 from public.games g join public.versions v on v.id=g.active and v.game_id=g.id where v.id=p_version and v.status='approved' and v.kind in ('demo','zip') and not g.paused and g.owner is distinct from u for share of g;
if not found then raise exception 'Published playable game required; creators cannot rate their own game';end if;
if not exists(select 1 from public.plays where user_id=u and version_id=p_version and seconds>=30 and inputs>0 and ended is not null) then raise exception 'Valid play required';end if;
insert into public.ratings(user_id,version_id,stars,recommend,review,updated) values(u,p_version,p_stars,p_recommend,coalesce(p_review,''),now()) on conflict(user_id,version_id) do update set stars=excluded.stars,recommend=excluded.recommend,review=excluded.review,updated=now();end$$;
revoke all on function arena_internal.start_play(uuid),arena_internal.rate_game(uuid,integer,boolean,text),public.start_play(uuid),public.rate_game(uuid,integer,boolean,text) from public,anon;
grant execute on function arena_internal.start_play(uuid),arena_internal.rate_game(uuid,integer,boolean,text),public.start_play(uuid),public.rate_game(uuid,integer,boolean,text) to authenticated;
notify pgrst,'reload schema';