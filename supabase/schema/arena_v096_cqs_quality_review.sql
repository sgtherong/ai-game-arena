
alter table public.versions add column cqs_status text not null default 'waiting' check(cqs_status in ('waiting','running','completed','error','legacy')), add column cqs_score integer check(cqs_score between 0 and 100), add column cqs_grade text check(cqs_grade in ('S','A','B','C','D')), add column release_class text check(release_class in ('service','prototype','below_standard')),add column cqs_checked_at timestamptz;
update public.versions set cqs_status='legacy',release_class='prototype' where status in ('approved','superseded');
create table public.cqs_reviews(version_id uuid primary key references public.versions(id),owner_id uuid not null references auth.users, screenshot_paths text[] not null check(cardinality(screenshot_paths) between 3 and 5), controls text not null check(length(trim(controls)) between 3 and 1000), concept text not null check(length(trim(concept)) between 10 and 1500), ai_use text not null check(length(trim(ai_use)) between 3 and 1000), consent_at timestamptz not null default now(), job uuid, attempts integer not null default 0, report jsonb, updated_at timestamptz not null default now());
alter table public.cqs_reviews enable row level security;
revoke all on public.cqs_reviews from public,anon,authenticated;
grant select on public.cqs_reviews to authenticated;
grant select,insert,update on public.cqs_reviews to service_role;
create policy cqs_owner_read on public.cqs_reviews for select to authenticated using(owner_id=auth.uid() or arena_internal.is_admin());
create function arena_internal.cqs_evidence(p_version uuid,p_paths text[],p_controls text,p_concept text,p_ai_use text) returns void language plpgsql security definer set search_path='' as $$
declare v public.versions;g public.games;n integer;begin
select * into v from public.versions where id=p_version for update;
if not found or v.status<>'pending' or v.kind<>'zip' or v.cqs_status not in ('waiting','error') then raise exception 'Pending ZIP version required; completed/running evidence is locked';end if;
select * into g from public.games where id=v.game_id;
if not exists(select 1 from public.profiles where id=auth.uid() and not suspended and role in ('developer','admin')) or g.owner is distinct from auth.uid() then raise exception 'Game owner required';end if;
if v.thumb_path is null then raise exception 'Thumbnail required; submit a new version with thumbnail';end if;
if p_paths is null or cardinality(p_paths) not between 3 and 5 or exists(select 1 from unnest(p_paths) x where x is null or x not like auth.uid()::text||'/cqs/'||p_version::text||'/%' or x !~ '\.(png|jpg|webp)$') then raise exception 'Three to five owned screenshot files required';end if;
select count(distinct x) into n from unnest(p_paths) x;
if n<>cardinality(p_paths) or exists(select 1 from unnest(p_paths) x where not exists(select 1 from storage.objects o where o.bucket_id='arena-private' and o.name=x)) then raise exception 'Screenshot missing or duplicate';end if;
insert into public.cqs_reviews(version_id,owner_id,screenshot_paths,controls,concept,ai_use) values(p_version,auth.uid(),p_paths,trim(p_controls),trim(p_concept),trim(p_ai_use)) on conflict(version_id) do update set screenshot_paths=excluded.screenshot_paths,controls=excluded.controls,concept=excluded.concept,ai_use=excluded.ai_use,consent_at=now(),updated_at=now();
update public.versions set cqs_status='waiting' where id=p_version;
end$$;
revoke all on function arena_internal.cqs_evidence(uuid,text[],text,text,text) from public,anon,authenticated;
grant execute on function arena_internal.cqs_evidence(uuid,text[],text,text,text) to authenticated;
create function public.cqs_evidence(p_version uuid,p_paths text[],p_controls text,p_concept text,p_ai_use text) returns void language sql security invoker set search_path='' as $$select arena_internal.cqs_evidence($1,$2,$3,$4,$5)$$;
revoke all on function public.cqs_evidence(uuid,text[],text,text,text) from public,anon,authenticated;
grant execute on function public.cqs_evidence(uuid,text[],text,text,text) to authenticated;
create function public.cqs_begin(p_version uuid,p_user uuid) returns jsonb language plpgsql security invoker set search_path='' as $$declare v public.versions;r public.cqs_reviews;j uuid;begin
if current_user<>'service_role' then raise exception 'Worker only';end if;
select * into v from public.versions where id=p_version for update;
if not found or v.status<>'pending' or v.kind<>'zip' or v.ai_status<>'passed' or v.ai_package_sha is null then raise exception 'SQS-passed pending ZIP required';end if;
select * into r from public.cqs_reviews where version_id=p_version for update;
if not found or not exists(select 1 from public.profiles where id=p_user and not suspended and (role='admin' or (role='developer' and id=r.owner_id))) then raise exception 'Evidence or authorization missing';end if;
if r.attempts>=3 or v.cqs_status='completed' or (v.cqs_status='running' and v.cqs_checked_at>now()-interval '5 minutes') then raise exception 'Review not available';end if;
perform pg_advisory_xact_lock(hashtextextended(r.owner_id::text,96));
if (select count(*) from public.cqs_reviews where owner_id=r.owner_id and attempts>0 and updated_at>now()-interval '1 day')>=10 then raise exception 'Daily review limit';end if;
j=gen_random_uuid();update public.cqs_reviews set job=j,attempts=attempts+1,updated_at=now() where version_id=p_version;
update public.versions set cqs_status='running',cqs_checked_at=now() where id=p_version;
return jsonb_build_object('job',j,'name',v.name,'genre',v.genre,'description',v.description,'path',v.path,'thumb_path',v.thumb_path,'sha',v.ai_package_sha,'screenshots',r.screenshot_paths,'controls',r.controls,'concept',r.concept,'ai_use',r.ai_use);end$$;
create function public.cqs_finish(p_version uuid,p_job uuid,p_levels jsonb,p_report jsonb) returns void language plpgsql security invoker set search_path='' as $$declare v public.versions;r public.cqs_reviews; k text; val integer;total numeric:=0;score integer;grade text;class text;w jsonb:='{"graphics":20,"ux":15,"gameplay":20,"content":15,"technical":10,"audio":5,"originality":10,"service":5}';begin
if current_user<>'service_role' then raise exception 'Worker only';end if;
select * into v from public.versions where id=p_version for update;
select * into r from public.cqs_reviews where version_id=p_version for update;
if not found or r.job is distinct from p_job or v.cqs_status<>'running' or v.status<>'pending' or v.ai_status<>'passed' then raise exception 'Review expired';end if;
if p_report is null or length(p_report::text)>20000 then raise exception 'Report invalid';end if;
if p_levels is null then update public.cqs_reviews set report=p_report,updated_at=now() where version_id=p_version;update public.versions set cqs_status='error',cqs_checked_at=now() where id=p_version;return;end if;
if jsonb_typeof(p_levels)<>'object' then raise exception 'Invalid levels';end if;
for k in select jsonb_object_keys(w) loop
if coalesce(p_levels->>k,'') !~ '^[0-4]$' then raise exception 'Invalid criterion level';end if;
val=(p_levels->>k)::integer;total:=total+val*(w->>k)::integer/4.0;end loop;
score:=round(total);grade:=case when score>=90 then 'S' when score>=80 then 'A' when score>=70 then 'B' when score>=60 then 'C' else 'D' end;class:=case when score>=70 then 'service' when score>=60 then 'prototype' else 'below_standard' end;
update public.cqs_reviews set report=p_report||jsonb_build_object('levels',p_levels,'score',score,'grade',grade,'class',class),updated_at=now() where version_id=p_version;
update public.versions set cqs_status='completed',cqs_score=score,cqs_grade=grade,release_class=class,cqs_checked_at=now() where id=p_version;
end$$;
revoke all on function public.cqs_begin(uuid,uuid),public.cqs_finish(uuid,uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.cqs_begin(uuid,uuid),public.cqs_finish(uuid,uuid,jsonb,jsonb) to service_role;
create function arena_internal.cqs_approval_gate() returns trigger language plpgsql security invoker set search_path='' as $$begin
if new.status='approved' and old.status is distinct from 'approved' and (new.cqs_status<>'completed' or new.cqs_score is null or new.cqs_score<60 or new.release_class not in ('service','prototype')) then raise exception 'CQS review must complete with at least 60 before approval';end if;return new;end$$;
revoke all on function arena_internal.cqs_approval_gate() from public,anon,authenticated;
create trigger cqs_approval_gate before update on public.versions for each row execute function arena_internal.cqs_approval_gate();
notify pgrst,'reload schema';
