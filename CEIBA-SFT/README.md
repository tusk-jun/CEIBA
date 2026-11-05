# Ceiba · Sistema web de reserva de citas médicas

Proyecto integrador de Análisis y Diseño de Software.
**Integrantes:** Joicer Prieto · Anthony Larios
**Aplicación publicada:** _(pegar aquí la URL de GitHub Pages del repositorio)_

## Qué hace
- **Paciente:** registro e inicio de sesión, perfil, búsqueda de franjas por especialidad, profesional y fecha, reserva, "Mis citas" y cancelación (mínimo 12 horas antes).
- **Profesional:** agenda propia y cambio de estado de sus citas (programada → confirmada → atendida, no asistió o cancelada).
- **Administrador:** especialidades, asignación de profesionales, generación y bloqueo de horarios, citas e indicadores.
- **Datos personales:** consentimiento al registrarse, descarga de una copia y eliminación (anonimización) desde Perfil. Política de tratamiento de datos dentro de la app.
- **Apariencia:** tema claro, oscuro o alto contraste; letra estándar, clásica o legible; tamaño normal hasta extra grande.

## Tecnologías
HTML5, CSS3 y JavaScript (módulos ES) · Supabase (Auth, PostgreSQL, RLS) · GitHub Pages.

## Estructura
```
index.html
assets/css/styles.css
assets/js/{config.js, api.js, ui.js, app.js}
sql/{esquema.sql, politicas_rls.sql, migracion_privacidad.sql, migracion_ajustes.sql, datos_prueba.sql}
```

## Instalación
1. Crea un proyecto en [Supabase](https://supabase.com).
2. En **SQL Editor** ejecuta, en este orden y una sola vez cada uno:
   `esquema.sql` → `politicas_rls.sql` → `migracion_privacidad.sql` → `migracion_ajustes.sql`.
3. En **Authentication > Users** crea (con *Auto Confirm User*): `admin.demo@example.com`, `medico1.demo@example.com`, `medico2.demo@example.com` y `paciente.demo@example.com`.
4. Ejecuta `datos_prueba.sql` (asigna roles y genera horarios de los próximos 14 días; se puede repetir).
5. En **Project Settings > API** copia la *Project URL* y la clave **publishable**, y pégalas en `assets/js/config.js`. **Nunca** uses la clave secret.
6. En GitHub: **Settings > Pages > Deploy from a branch > main / (root)**.

> Si reutilizas el mismo proyecto de Supabase en otro repositorio, no repitas los pasos 1 a 4: solo actualiza `config.js` y activa Pages.

## Credenciales de demostración
Los cuatro correos del paso 3 con la contraseña de demostración definida por el equipo: _(escribirla aquí; usar una exclusiva para la demo)_.

## Decisiones técnicas
- **Doble reserva:** `reservar_cita()` cambia la franja con un `UPDATE ... WHERE estado = 'disponible'` atómico y un índice único parcial sobre las citas activas.
- **Cancelación:** la cita se conserva como `cancelada` y la franja vuelve a quedar disponible.
- **Horarios:** una restricción `EXCLUDE` impide franjas superpuestas; una franja reservada no se mueve ni se borra.
- **Roles:** nacen siempre como `paciente`; solo el administrador los cambia. El cliente solo puede actualizar nombre, documento, teléfono y fecha de nacimiento (permisos por columna, más un trigger de respaldo).
- **Citas:** no tienen políticas de escritura directa; solo se modifican con funciones `security definer` que validan dueño, rol y transición de estado.
- **Privacidad:** el documento del paciente se muestra enmascarado a profesionales y administración.
- **Interfaz:** sin `innerHTML`, política de seguridad de contenido por `<meta>`, hora fija `America/Bogota`.

## Seguridad
La clave publishable es pública por diseño; la protección real está en RLS. No subas claves secret ni contraseñas personales al repositorio.

## Limitaciones conocidas
- No hay pantalla para activar o desactivar pacientes ni editar profesionales (se hace por SQL).
- Un profesional debe registrarse primero; el administrador lo asigna por su correo.
- GitHub Pages no permite cabeceras HTTP, por lo que algunas protecciones (por ejemplo `frame-ancestors`) quedan fuera de alcance.
- El correo de contacto de la política de datos es un marcador: reemplázalo por uno real.
