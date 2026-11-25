
create function public.ai_budget_defer99(p_kind text,p_version uuid,p_job uuid) returns void language plpgsql security invoker set search_path='' as $$
begin
if current_user<>'service_role' then raise exception 'Worker only';end if;
if p_kind='sqs' then
update public.versions set ai_status='error',ai_attempts=greatest(ai_attempts-1,0),ai_checked_at=now(),ai_report=jsonb_build_object('reason','AI call cap reached; no provider call was made. Retry after reset.','reason_ko','AI 호출 한도에 도달했습니다. API 호출은 발생하지 않았으며 한도 초기화 후 재시도할 수 있습니다.') where id=p_version and status='pending' and ai_status='running' and ai_job=p_job;
elsif p_kind='cqs' then
perform 1 from public.versions where id=p_version and status='pending' and cqs_status='running' for update;
if found then
update public.cqs_reviews set attempts=greatest(attempts-1,0),report=jsonb_build_object('summary','AI call cap reached; no provider call was made. Retry after reset.','summary_ko','AI 호출 한도에 도달했습니다. API 호출은 발생하지 않았으며 한도 초기화 후 재시도할 수 있습니다.'),updated_at=now() where version_id=p_version and job=p_job;
if found then update public.versions set cqs_status='error',cqs_checked_at=now() where id=p_version;end if;
end if;
else raise exception 'Invalid kind';end if;
end$$;
revoke all on function public.ai_budget_defer99(text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ai_budget_defer99(text,uuid,uuid) to service_role;
notify pgrst,'reload schema';