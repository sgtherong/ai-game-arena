
create table arena_internal.ai_usage99(id uuid primary key default gen_random_uuid(),kind text not null check(kind in ('sqs','cqs','planner')),version_id uuid references public.versions(id),model text not null check(length(model)<=100),created timestamptz not null default now(),state text not null default 'reserved' check(state in ('reserved','ok','error')),input_tokens integer check(input_tokens>=0),output_tokens integer check(output_tokens>=0),finished timestamptz);
create index ai_usage99_created_idx on arena_internal.ai_usage99(created);
create table arena_internal.ai_limits99(id boolean primary key default true check(id),daily_cap integer not null check(daily_cap between 0 and 100),monthly_cap integer not null check(monthly_cap between 0 and 1000),planner_enabled boolean not null default false);
insert into arena_internal.ai_limits99(id,daily_cap,monthly_cap,planner_enabled) values(true,10,100,false);
alter table arena_internal.ai_usage99 enable row level security;
alter table arena_internal.ai_limits99 enable row level security;
revoke all on arena_internal.ai_usage99,arena_internal.ai_limits99 from public,anon,authenticated;
grant select,insert,update on arena_internal.ai_usage99 to service_role;
grant select on arena_internal.ai_limits99 to service_role;
create function public.ai_reserve99(p_kind text,p_version uuid,p_model text) returns uuid language plpgsql security invoker set search_path='' as $$
declare l arena_internal.ai_limits99;v public.versions;j uuid;begin
if current_user<>'service_role' then raise exception 'Worker only';end if;
if p_kind not in ('sqs','cqs','planner') or p_model is null or length(p_model)>100 then raise exception 'Invalid request';end if;
select * into v from public.versions where id=p_version;
if not found or v.status<>'pending' or (p_kind='sqs' and v.ai_status<>'running') or (p_kind='cqs' and v.cqs_status<>'running') or (p_kind='planner' and v.runtime_status<>'running') then raise exception 'Invalid review state';end if;
perform pg_advisory_xact_lock(99001);
select * into l from arena_internal.ai_limits99 where id;
if p_kind='planner' and not l.planner_enabled then return null;end if;
if (select count(*) from arena_internal.ai_usage99 where created>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC')>=l.daily_cap or (select count(*) from arena_internal.ai_usage99 where created>=date_trunc('month',now() at time zone 'UTC') at time zone 'UTC')>=l.monthly_cap then return null;end if;
insert into arena_internal.ai_usage99(kind,version_id,model) values(p_kind,p_version,p_model) returning id into j;return j;
end$$;
create function public.ai_finish99(p_id uuid,p_ok boolean,p_input integer,p_output integer) returns void language plpgsql security invoker set search_path='' as $$begin
if current_user<>'service_role' then raise exception 'Worker only';end if;
if p_input<0 or p_output<0 then raise exception 'Invalid tokens';end if;
update arena_internal.ai_usage99 set state=case when p_ok then 'ok' else 'error' end,input_tokens=p_input,output_tokens=p_output,finished=now() where id=p_id and state='reserved';
end$$;
revoke all on function public.ai_reserve99(text,uuid,text),public.ai_finish99(uuid,boolean,integer,integer) from public,anon,authenticated;
grant execute on function public.ai_reserve99(text,uuid,text),public.ai_finish99(uuid,boolean,integer,integer) to service_role;
create function arena_internal.qa_dashboard99() returns jsonb language plpgsql security definer set search_path='' as $$
declare d timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';m timestamptz:=date_trunc('month',now() at time zone 'UTC') at time zone 'UTC';l arena_internal.ai_limits99;begin
if not arena_internal.is_admin() then raise exception 'Admin required';end if;
select * into l from arena_internal.ai_limits99 where id;
return jsonb_build_object('limits',jsonb_build_object('daily',l.daily_cap,'monthly',l.monthly_cap,'planner_enabled',l.planner_enabled),'today',(select count(*) from arena_internal.ai_usage99 where created>=d),'month',(select count(*) from arena_internal.ai_usage99 where created>=m),'input_tokens',(select coalesce(sum(input_tokens),0) from arena_internal.ai_usage99 where created>=m),'output_tokens',(select coalesce(sum(output_tokens),0) from arena_internal.ai_usage99 where created>=m),'unknown_usage',(select count(*) from arena_internal.ai_usage99 where created>=m and (input_tokens is null or output_tokens is null)),'by_kind',(select coalesce(jsonb_object_agg(kind,n),'{}'::jsonb) from (select kind,count(*) n from arena_internal.ai_usage99 where created>=m group by kind)x),'queue',(select coalesce(jsonb_object_agg(runtime_status,n),'{}'::jsonb) from (select runtime_status,count(*) n from public.versions where status='pending' group by runtime_status)x),'pending_sqs',(select count(*) from public.versions where status='pending' and ai_status<>'passed'),'pending_cqs',(select count(*) from public.versions where status='pending' and ai_status='passed' and cqs_status<>'completed'),'rqs_measured',(select count(*) from public.versions where rqs_score is not null),'recent',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select name,label,status,ai_status,cqs_status,runtime_status,rqs_score from public.versions order by created desc limit 30)x));
end$$;
create function public.qa_dashboard99() returns jsonb language sql security invoker set search_path='' as $$select arena_internal.qa_dashboard99()$$;
revoke all on function arena_internal.qa_dashboard99(),public.qa_dashboard99() from public,anon,authenticated;
grant execute on function arena_internal.qa_dashboard99(),public.qa_dashboard99() to authenticated;
create function arena_internal.qa_limits99(p_daily int,p_monthly int,p_planner boolean) returns void language plpgsql security definer set search_path='' as $$begin
if not arena_internal.is_admin() then raise exception 'Admin required';end if;
if p_daily is null or p_monthly is null or p_planner is null or p_daily not between 0 and 100 or p_monthly not between 0 and 1000 then raise exception 'Invalid limit';end if;
perform pg_advisory_xact_lock(99001);
update arena_internal.ai_limits99 set daily_cap=p_daily,monthly_cap=p_monthly,planner_enabled=p_planner where id;
insert into public.admin_audit(actor,action,target,detail) values(auth.uid(),'qa_limits','ai_limits99',jsonb_build_object('daily',p_daily,'monthly',p_monthly,'planner',p_planner)::text);
end$$;
create function public.qa_limits99(p_daily int,p_monthly int,p_planner boolean) returns void language sql security invoker set search_path='' as $$select arena_internal.qa_limits99($1,$2,$3)$$;
revoke all on function arena_internal.qa_limits99(int,int,boolean),public.qa_limits99(int,int,boolean) from public,anon,authenticated;
grant execute on function arena_internal.qa_limits99(int,int,boolean),public.qa_limits99(int,int,boolean) to authenticated;
notify pgrst,'reload schema';
