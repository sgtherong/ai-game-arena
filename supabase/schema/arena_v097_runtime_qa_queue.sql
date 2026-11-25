
alter table public.versions add column runtime_status text not null default 'not_requested' check(runtime_status in ('not_requested','queued','running','passed','failed','error','legacy')),add column runtime_checked_at timestamptz;
update public.versions set runtime_status='legacy' where status in ('approved','superseded');
create table public.runtime_reviews(version_id uuid primary key references public.versions(id),owner_id uuid not null references auth.users,requested_by uuid not null references auth.users,package_sha text not null check(package_sha ~ '^[a-f0-9]{64}$'),requested_at timestamptz not null default now(),updated_at timestamptz not null default now(),attempts int not null default 0,lease uuid,lease_until timestamptz,report jsonb);
alter table public.runtime_reviews enable row level security;
revoke all on public.runtime_reviews from public,anon,authenticated;
grant select(version_id,owner_id,requested_at,updated_at,attempts,report) on public.runtime_reviews to authenticated;
grant select,update,insert on public.runtime_reviews to service_role;
create policy runtime_owner_read on public.runtime_reviews for select to authenticated using(owner_id=auth.uid() or arena_internal.is_admin());
create function arena_internal.runtime_request(p_version uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.versions;g public.games;r public.runtime_reviews;begin
if not arena_internal.is_admin() then raise exception 'Admin required';end if;
select * into v from public.versions where id=p_version for update;
if not found or v.status<>'pending' or v.kind<>'zip' or v.ai_status<>'passed' or v.ai_package_sha is null or v.cqs_status<>'completed' or v.cqs_score<60 then raise exception 'SQS and CQS eligible pending ZIP required';end if;
select * into g from public.games where id=v.game_id;
select * into r from public.runtime_reviews where version_id=p_version;
if found and (r.attempts>=3 or v.runtime_status in ('queued','passed') or (v.runtime_status='running' and r.lease_until>now())) then raise exception 'Already queued, completed or retry limit';end if;
if (select count(*) from public.versions where runtime_status in ('queued','running') and status='pending')>=20 then raise exception 'QA queue full';end if;
insert into public.runtime_reviews(version_id,owner_id,requested_by,package_sha) values(v.id,g.owner,auth.uid(),v.ai_package_sha) on conflict(version_id) do update set requested_by=excluded.requested_by,requested_at=now(),updated_at=now(),lease=null,lease_until=null,report=null;
update public.versions set runtime_status='queued',runtime_checked_at=now() where id=v.id;
insert into public.admin_audit(actor,action,target,detail) values(auth.uid(),'runtime_request',v.id::text,'Runtime QA requested');
end$$;
revoke all on function arena_internal.runtime_request(uuid) from public,anon,authenticated;
grant execute on function arena_internal.runtime_request(uuid) to authenticated;
create function public.runtime_request(p_version uuid) returns void language sql security invoker set search_path='' as $$select arena_internal.runtime_request($1)$$;
revoke all on function public.runtime_request(uuid) from public,anon,authenticated;
grant execute on function public.runtime_request(uuid) to authenticated;
create function public.runtime_claim() returns jsonb language plpgsql security invoker set search_path='' as $$
declare v public.versions;r public.runtime_reviews;j uuid;begin
if current_user<>'service_role' then raise exception 'Worker only';end if;
select z.* into v from public.versions z join public.runtime_reviews t on t.version_id=z.id where z.status='pending' and z.ai_status='passed' and z.cqs_status='completed' and z.cqs_score>=60 and z.ai_package_sha=t.package_sha and t.attempts<3 and (z.runtime_status='queued' or (z.runtime_status='running' and t.lease_until<now())) order by t.requested_at for update of z skip locked limit 1;
if not found then return null;end if;
j=gen_random_uuid();update public.runtime_reviews set lease=j,lease_until=now()+interval '10 minutes',attempts=attempts+1,updated_at=now() where version_id=v.id returning * into r;
update public.versions set runtime_status='running',runtime_checked_at=now() where id=v.id;
return jsonb_build_object('version_id',v.id,'lease',j,'path',v.path,'sha',r.package_sha,'genre',v.genre);
end$$;
create function public.runtime_finish(p_version uuid,p_lease uuid,p_sha text,p_report jsonb) returns text language plpgsql security invoker set search_path='' as $$
declare v public.versions;r public.runtime_reviews;d jsonb;k text;passed boolean:=true;state text;begin
if current_user<>'service_role' then raise exception 'Worker only';end if;
select * into v from public.versions where id=p_version for update;select * into r from public.runtime_reviews where version_id=p_version for update;
if not found or v.status<>'pending' or v.runtime_status<>'running' or r.lease is distinct from p_lease or r.lease_until<now() or p_sha is distinct from r.package_sha or p_sha is distinct from v.ai_package_sha then raise exception 'Invalid or expired QA lease';end if;
if p_report is null or jsonb_typeof(p_report)<>'object' or length(p_report::text)>12000 then raise exception 'Invalid report';end if;
if p_report->>'outcome'='error' then state:='error';else
if p_report->>'outcome' is distinct from 'completed' or p_report->>'policy' is distinct from 'runtime-smoke-v1' then raise exception 'Invalid report policy';end if;
foreach k in array array['desktop','mobile'] loop
d:=p_report->k;
if jsonb_typeof(d) is distinct from 'object' or jsonb_typeof(d->'loaded') is distinct from 'boolean' or jsonb_typeof(d->'visible') is distinct from 'boolean' or jsonb_typeof(d->'input_dispatched') is distinct from 'boolean' or jsonb_typeof(d->'responsive') is distinct from 'boolean' or coalesce(d->>'page_errors','') !~ '^[0-9]{1,4}$' or coalesce(d->>'blocked_requests','') !~ '^[0-9]{1,4}$' then raise exception 'Invalid viewport report';end if;
passed:=passed and (d->>'loaded')::boolean and (d->>'visible')::boolean and (d->>'input_dispatched')::boolean and (d->>'responsive')::boolean and (d->>'page_errors')::int=0 and (d->>'blocked_requests')::int=0;
end loop;
state:=case when passed then 'passed' else 'failed' end;end if;
update public.runtime_reviews set report=p_report||jsonb_build_object('status',state),lease=null,lease_until=null,updated_at=now() where version_id=p_version;
update public.versions set runtime_status=state,runtime_checked_at=now() where id=p_version;
return state;end$$;
revoke all on function public.runtime_claim(),public.runtime_finish(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.runtime_claim(),public.runtime_finish(uuid,uuid,text,jsonb) to service_role;
create function arena_internal.runtime_approval_gate() returns trigger language plpgsql security invoker set search_path='' as $$begin
if new.status='approved' and old.status is distinct from 'approved' and new.runtime_status not in ('not_requested','passed') then raise exception 'Requested runtime QA must pass before approval';end if;return new;end$$;
revoke all on function arena_internal.runtime_approval_gate() from public,anon,authenticated;
create trigger runtime_approval_gate before update on public.versions for each row execute function arena_internal.runtime_approval_gate();
notify pgrst,'reload schema';
