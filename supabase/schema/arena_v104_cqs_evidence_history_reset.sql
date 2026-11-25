create table arena_internal.cqs_evidence_history104(
 id uuid primary key default gen_random_uuid(), version_id uuid not null references public.versions(id), owner_id uuid not null, archived_at timestamptz not null default now(), action text not null check(action in ('replace','reset')), snapshot jsonb not null
);
alter table arena_internal.cqs_evidence_history104 enable row level security;
revoke all on arena_internal.cqs_evidence_history104 from public,anon,authenticated;
create function arena_internal.archive_cqs_evidence104() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then
 insert into arena_internal.cqs_evidence_history104(version_id,owner_id,action,snapshot) values(old.version_id,old.owner_id,'reset',to_jsonb(old));return old;
 end if;
 if (old.screenshot_paths,old.controls,old.concept,old.ai_use) is distinct from (new.screenshot_paths,new.controls,new.concept,new.ai_use) then
 insert into arena_internal.cqs_evidence_history104(version_id,owner_id,action,snapshot) values(old.version_id,old.owner_id,'replace',to_jsonb(old));
 end if;
 return new;
end$$;
revoke all on function arena_internal.archive_cqs_evidence104() from public,anon,authenticated;
create trigger cqs_evidence_history104 before update of screenshot_paths,controls,concept,ai_use or delete on public.cqs_reviews for each row execute function arena_internal.archive_cqs_evidence104();
create function arena_internal.cqs_reset104(p_version uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.versions;r public.cqs_reviews;begin
select * into v from public.versions where id=p_version for update;
if not found or v.status<>'pending' or v.cqs_status not in ('waiting','error') or v.kind<>'zip' then raise exception 'Only pending, inactive CQS evidence may be reset';end if;
if not exists(select 1 from public.games g join public.profiles p on p.id=g.owner where g.id=v.game_id and g.owner=auth.uid() and not p.suspended and p.role in ('developer','admin')) then raise exception 'Game owner required';end if;
select * into r from public.cqs_reviews where version_id=p_version for update;
if not found then return;end if;
if r.attempts<>0 or r.job is not null or r.report is not null then raise exception 'Review already attempted: replace evidence without resetting attempts';end if;
delete from public.cqs_reviews where version_id=p_version;
update public.versions set cqs_status='waiting' where id=p_version;
end$$;
create function public.cqs_reset104(p_version uuid) returns void language sql security invoker set search_path='' as $$select arena_internal.cqs_reset104($1)$$;
revoke all on function arena_internal.cqs_reset104(uuid),public.cqs_reset104(uuid) from public,anon,authenticated;
grant execute on function arena_internal.cqs_reset104(uuid),public.cqs_reset104(uuid) to authenticated;
notify pgrst,'reload schema';