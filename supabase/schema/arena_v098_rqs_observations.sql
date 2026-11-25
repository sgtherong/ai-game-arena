
alter table public.versions add column rqs_score integer check(rqs_score between 0 and 100),add column rqs_policy text;
create function arena_internal.rqs_from_report() returns trigger language plpgsql security invoker set search_path='' as $$
declare d jsonb;k text;total numeric:=0;part integer;fps numeric;ms integer;changed boolean;begin
if new.report is null then update public.versions set rqs_score=null,rqs_policy=null where id=new.version_id;return new;end if;
if new.report->>'evidence_policy' is distinct from 'rqs-observation-v1' or new.report->>'outcome' is distinct from 'completed' then update public.versions set rqs_score=null,rqs_policy=null where id=new.version_id;return new;end if;
foreach k in array array['desktop','mobile'] loop
d:=new.report->k;
if jsonb_typeof(d) is distinct from 'object' or jsonb_typeof(d->'screen_changed') is distinct from 'boolean' or coalesce(d->>'raf_fps','') !~ '^[0-9]{1,3}(\.[0-9]{1,2})?$' or coalesce(d->>'load_ms','') !~ '^[0-9]{1,6}$' or coalesce(d->>'actions','') !~ '^[0-9]{1,2}$' or coalesce(d->>'before_sha','') !~ '^[a-f0-9]{64}$' or coalesce(d->>'after_sha','') !~ '^[a-f0-9]{64}$' then raise exception 'Invalid RQS evidence';end if;
fps:=(d->>'raf_fps')::numeric;ms:=(d->>'load_ms')::int;changed:=(d->>'screen_changed')::boolean;
if fps>240 or (d->>'actions')::int>12 or changed is distinct from ((d->>'before_sha')<>(d->>'after_sha')) then raise exception 'Inconsistent RQS evidence';end if;
part:=case when (d->>'loaded')::boolean then 20 else 0 end + case when (d->>'visible')::boolean then 15 else 0 end + case when (d->>'responsive')::boolean then 15 else 0 end + case when (d->>'page_errors')::int=0 and (d->>'blocked_requests')::int=0 then 20 else 0 end + case when (d->>'input_dispatched')::boolean and (d->>'actions')::int>0 then 10 else 0 end + case when changed then 5 else 0 end + case when fps>=50 then 10 when fps>=30 then 7 when fps>=15 then 3 else 0 end + case when ms<=2000 then 5 when ms<=5000 then 3 else 0 end;
total:=total+part;
end loop;
update public.versions set rqs_score=round(total/2),rqs_policy='rqs-observation-v1' where id=new.version_id;
return new;end$$;
revoke all on function arena_internal.rqs_from_report() from public,anon,authenticated;
create trigger rqs_report_update after update of report on public.runtime_reviews for each row execute function arena_internal.rqs_from_report();
notify pgrst,'reload schema';
