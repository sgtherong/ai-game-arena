create table arena_internal.showcase112(
 version_id uuid primary key references public.versions(id) on delete cascade,
 creator_name text not null default '' check(char_length(creator_name)<=80),
 gallery_paths text[] not null default '{}' check(cardinality(gallery_paths)<=5),
 updated_at timestamptz not null default now()
);
alter table arena_internal.showcase112 enable row level security;
revoke all on arena_internal.showcase112 from public,anon,authenticated;
create function arena_internal.showcase_save112(p_version uuid,p_creator text,p_gallery boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.versions; paths text[]:='{}'; display_name text:=trim(coalesce(p_creator,'')); begin
select * into v from public.versions where id=p_version for update;
if not found or v.status not in ('pending','approved') or not exists(select 1 from public.games g join public.profiles p on p.id=g.owner where g.id=v.game_id and g.owner=auth.uid() and not p.suspended and p.role in ('developer','admin')) then raise exception 'Game owner and eligible version required';end if;
if char_length(display_name)>80 then raise exception 'Display name max 80 characters';end if;
if p_gallery is true then
 if v.cqs_status<>'completed' then raise exception 'Completed CQS required for gallery';end if;
 select screenshot_paths into paths from public.cqs_reviews where version_id=p_version and owner_id=auth.uid();
 if paths is null or cardinality(paths) not between 3 and 5 or exists(select 1 from unnest(paths) x where x not like auth.uid()::text||'/cqs/'||p_version::text||'/%' or not exists(select 1 from storage.objects o where o.bucket_id='arena-private' and o.name=x)) then raise exception 'Review screenshots unavailable';end if;
end if;
insert into arena_internal.showcase112(version_id,creator_name,gallery_paths) values(p_version,display_name,paths) on conflict(version_id) do update set creator_name=excluded.creator_name,gallery_paths=excluded.gallery_paths,updated_at=now();
return jsonb_build_object('creator_name',display_name,'gallery_enabled',cardinality(paths)>0);
end$$;
create function arena_internal.showcase_settings112(p_version uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d arena_internal.showcase112;begin
if not exists(select 1 from public.versions v join public.games g on g.id=v.game_id join public.profiles p on p.id=g.owner where v.id=p_version and g.owner=auth.uid() and not p.suspended and p.role in ('developer','admin')) then raise exception 'Game owner required';end if;
select * into d from arena_internal.showcase112 where version_id=p_version;
return jsonb_build_object('creator_name',coalesce(d.creator_name,''),'gallery_enabled',coalesce(cardinality(d.gallery_paths)>0,false));end$$;
create function arena_internal.showcase_gallery_visible112(p_path text) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from arena_internal.showcase112 s join public.versions v on v.id=s.version_id join public.games g on g.id=v.game_id and g.active=v.id join public.profiles p on p.id=g.owner and not p.suspended where v.status='approved' and v.cqs_status='completed' and not g.paused and p_path=any(s.gallery_paths))
$$;
create policy arena_showcase_read112 on storage.objects for select to anon,authenticated using(bucket_id='arena-private' and arena_internal.showcase_gallery_visible112(name));
create function arena_internal.game_detail112(p_game text) returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('game_id',g.id,'version_id',v.id,'name',v.name,'version',v.label,'genre',v.genre,'description',v.description,'kind',v.kind,'creator_name',case when g.owner is null then 'GAMENOVENT' else nullif(s.creator_name,'') end,'gallery_paths',coalesce(s.gallery_paths,'{}'::text[]),'sqs',case when v.ai_status='passed' then v.ai_score end,'cqs',case when v.cqs_status='completed' then v.cqs_score end,'grade',case when v.cqs_status='completed' then v.cqs_grade end,'release_class',v.release_class,'rqs',case when v.runtime_status='passed' then v.rqs_score end,'review_count',a.n,'average_stars',case when a.n>=5 then round(a.stars,2) end,'recommend_pct',case when a.n>=5 then round(a.recommend*100,1) end,'stars',case when a.n>=5 then a.hist end)
from public.games g join public.versions v on v.id=g.active and v.game_id=g.id left join public.profiles p on p.id=g.owner left join arena_internal.showcase112 s on s.version_id=v.id
cross join lateral(select count(*) n,avg(r.stars) stars,avg(r.recommend::int) recommend,jsonb_build_array(count(*) filter(where r.stars=1),count(*) filter(where r.stars=2),count(*) filter(where r.stars=3),count(*) filter(where r.stars=4),count(*) filter(where r.stars=5)) hist from public.ratings r join public.profiles rp on rp.id=r.user_id and not rp.suspended where r.version_id=v.id and r.user_id is distinct from g.owner and exists(select 1 from public.plays pl where pl.user_id=r.user_id and pl.version_id=v.id and pl.ended is not null and pl.seconds>=30 and pl.inputs>0)) a
where g.id=p_game and not g.paused and v.status='approved' and (g.owner is null or (p.id is not null and not p.suspended))
$$;
create function public.showcase_save112(p_version uuid,p_creator text,p_gallery boolean) returns jsonb language sql security invoker set search_path='' as $$select arena_internal.showcase_save112($1,$2,$3)$$;
create function public.showcase_settings112(p_version uuid) returns jsonb language sql stable security invoker set search_path='' as $$select arena_internal.showcase_settings112($1)$$;
create function public.game_detail112(p_game text) returns jsonb language sql stable security invoker set search_path='' as $$select arena_internal.game_detail112($1)$$;
revoke all on function arena_internal.showcase_save112(uuid,text,boolean),arena_internal.showcase_settings112(uuid),arena_internal.showcase_gallery_visible112(text),arena_internal.game_detail112(text),public.showcase_save112(uuid,text,boolean),public.showcase_settings112(uuid),public.game_detail112(text) from public,anon,authenticated;
grant execute on function arena_internal.showcase_save112(uuid,text,boolean),arena_internal.showcase_settings112(uuid),public.showcase_save112(uuid,text,boolean),public.showcase_settings112(uuid) to authenticated;
grant execute on function arena_internal.showcase_gallery_visible112(text),arena_internal.game_detail112(text),public.game_detail112(text) to anon,authenticated;
notify pgrst,'reload schema';