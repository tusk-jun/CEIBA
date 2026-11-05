-- Privacidad (Ley 1581 de 2012, habeas data). Ejecutar UNA vez despues de esquema.sql y politicas_rls.sql.
create table if not exists public.consentimientos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  version text not null, accepted_at timestamptz not null default now());
alter table public.consentimientos enable row level security;
revoke all on public.consentimientos from anon, authenticated;
grant select on public.consentimientos to authenticated;
drop policy if exists cons_select on public.consentimientos;
create policy cons_select on public.consentimientos for select to authenticated using (user_id = auth.uid());

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, nombres)
  values (new.id, coalesce(nullif(left(trim(new.raw_user_meta_data->>'nombres'),80),''), split_part(new.email,'@',1)));
  if new.raw_user_meta_data->>'acepta_datos' = 'true' then
    insert into public.consentimientos(user_id, version) values (new.id, left(coalesce(new.raw_user_meta_data->>'version_politica','2026-10'),20));
  end if;
  return new;
end $$;

create or replace function public.proteger_perfil() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and coalesce(public.app_rol(),'') <> 'admin'
     and coalesce(current_setting('app.anonimizando', true),'') <> '1' then
    new.id := old.id; new.rol := old.rol; new.activo := old.activo;
  end if;
  return new;
end $$;

create function public.aceptar_politica(p_version text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'no_autorizado'; end if;
  insert into public.consentimientos(user_id, version) values (auth.uid(), left(p_version,20));
end $$;

create function public.exportar_mis_datos() returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'perfil', (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'consentimientos', coalesce((select jsonb_agg(to_jsonb(c) - 'user_id') from public.consentimientos c where c.user_id = auth.uid()), '[]'),
    'citas', coalesce((select jsonb_agg(jsonb_build_object('fecha', s.fecha, 'hora', s.hora_inicio, 'estado', a.estado, 'motivo', a.motivo))
       from public.appointments a join public.schedules s on s.id = a.schedule_id where a.patient_id = auth.uid()), '[]')) $$;

-- Supresion: anonimiza datos personales y cancela citas futuras; conserva el historial sin identificar a la persona.
create function public.anonimizar_mi_cuenta() returns void language plpgsql security definer set search_path = '' as $$
declare a record;
begin
  if public.app_rol() <> 'paciente' then raise exception 'no_autorizado'; end if;
  for a in select ap.id from public.appointments ap join public.schedules s on s.id = ap.schedule_id
           where ap.patient_id = auth.uid() and ap.estado in ('programada','confirmada') and (s.fecha + s.hora_inicio) > public.ahora_local() loop
    perform public.cambiar_estado_cita(a.id, 'cancelada');
  end loop;
  update public.appointments set motivo = null where patient_id = auth.uid();
  perform set_config('app.anonimizando', '1', true);
  update public.profiles set nombres = 'Cuenta anonimizada', documento = null, telefono = null, fecha_nacimiento = null, activo = false where id = auth.uid();
end $$;

-- Minimizacion: profesionales y admin ven el documento enmascarado.
create or replace function public.listar_citas(p_desde date default null, p_hasta date default null)
returns table(id uuid, fecha date, hora_inicio time, hora_fin time, profesional text, especialidad text,
              paciente text, documento text, estado text, motivo text)
language sql stable security definer set search_path = '' as $$
  select a.id, s.fecha, s.hora_inicio, s.hora_fin, pf.nombres, e.nombre, pa.nombres,
         case when public.app_rol() = 'paciente' then pa.documento else '•••' || right(coalesce(pa.documento,''), 3) end, a.estado, a.motivo
  from public.appointments a join public.schedules s on s.id = a.schedule_id
  join public.professionals p on p.id = a.professional_id join public.profiles pf on pf.id = p.profile_id
  join public.specialties e on e.id = p.specialty_id join public.profiles pa on pa.id = a.patient_id
  where (public.app_rol() = 'admin' or (public.app_rol() = 'paciente' and a.patient_id = auth.uid())
     or (public.app_rol() = 'profesional' and p.profile_id = auth.uid()))
    and (p_desde is null or s.fecha >= p_desde) and (p_hasta is null or s.fecha <= p_hasta)
  order by s.fecha, s.hora_inicio limit 500 $$;

revoke all on function public.aceptar_politica, public.exportar_mis_datos, public.anonimizar_mi_cuenta from public, anon;
grant execute on function public.aceptar_politica, public.exportar_mis_datos, public.anonimizar_mi_cuenta to authenticated;
-- Usuarios que ya existian deben aceptar la politica al entrar (la app se lo pide).
