-- LINKED: initial Supabase/PostgreSQL schema (draft, requires security review)
-- Run in a fresh Supabase project only after reviewing requirements.
-- Do not use production personal data until RLS policies are reviewed and tested.

create extension if not exists pgcrypto;

create type public.learning_type as enum ('single_session', 'full_course');
create type public.learning_mode as enum ('online', 'offline');
create type public.request_status as enum ('pending', 'confirmed', 'rejected', 'cancelled', 'completed', 'reviewed');
create type public.mentor_verification_status as enum ('not_submitted', 'pending', 'approved', 'rejected', 'trial');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  student_id text,
  study_program text,
  cohort_year integer,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mentor_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  verification_status public.mentor_verification_status not null default 'not_submitted',
  verification_notes text,
  teaching_bio text,
  teaching_experience text,
  availability_notes text,
  online_available boolean not null default true,
  offline_available boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category text,
  created_at timestamptz not null default now()
);

create table public.mentor_expertise (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.mentor_profiles(user_id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  topics text[] not null default '{}',
  evidence_note text,
  created_at timestamptz not null default now(),
  unique (mentor_id, subject_id)
);

create table public.learning_requests (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.profiles(id) on delete cascade,
  mentor_id uuid not null references public.mentor_profiles(user_id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  topic text not null,
  learning_objective text not null,
  current_understanding text,
  learning_type public.learning_type not null,
  requested_week text,
  preferred_date date not null,
  preferred_time time not null,
  duration_minutes integer not null check (duration_minutes between 30 and 240),
  mode public.learning_mode not null,
  location_or_link text,
  additional_notes text,
  status public.request_status not null default 'pending',
  mentor_response_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (learner_id <> mentor_id)
);

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  learning_request_id uuid references public.learning_requests(id) on delete set null,
  learner_id uuid not null references public.profiles(id) on delete cascade,
  mentor_id uuid not null references public.mentor_profiles(user_id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  title text not null,
  learning_objective text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  sequence_no integer not null check (sequence_no > 0),
  title text not null,
  topic text,
  material_url text,
  exercise_description text,
  assignment_description text,
  recommended_resources text,
  created_at timestamptz not null default now(),
  unique (course_id, sequence_no)
);

create table public.module_progress (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.course_modules(id) on delete cascade,
  learner_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'not_started' check (status in ('not_started','in_progress','completed')),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (module_id, learner_id)
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  learning_request_id uuid references public.learning_requests(id) on delete set null,
  course_id uuid references public.courses(id) on delete set null,
  learner_id uuid not null references public.profiles(id) on delete cascade,
  mentor_id uuid not null references public.mentor_profiles(user_id) on delete restrict,
  topic text not null,
  starts_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes between 30 and 240),
  mode public.learning_mode not null,
  location_or_link text,
  status public.request_status not null default 'confirmed',
  summary text,
  next_steps text,
  created_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references public.sessions(id) on delete cascade,
  learner_id uuid not null references public.profiles(id) on delete cascade,
  mentor_id uuid not null references public.mentor_profiles(user_id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  moderation_status text not null default 'pending' check (moderation_status in ('pending','published','hidden')),
  created_at timestamptz not null default now(),
  check (learner_id <> mentor_id)
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  organizer text,
  category text not null,
  description text,
  registration_url text,
  starts_at timestamptz,
  ends_at timestamptz,
  tags text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index learning_requests_learner_status_idx on public.learning_requests (learner_id, status, created_at desc);
create index learning_requests_mentor_status_idx on public.learning_requests (mentor_id, status, created_at desc);
create index mentor_expertise_subject_idx on public.mentor_expertise (subject_id);
create index sessions_learner_starts_idx on public.sessions (learner_id, starts_at desc);
create index sessions_mentor_starts_idx on public.sessions (mentor_id, starts_at desc);
create index opportunities_status_start_idx on public.opportunities (status, starts_at);

-- Enable RLS; policies should be written and tested before exposing tables via the API.
alter table public.profiles enable row level security;
alter table public.mentor_profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.mentor_expertise enable row level security;
alter table public.learning_requests enable row level security;
alter table public.courses enable row level security;
alter table public.course_modules enable row level security;
alter table public.module_progress enable row level security;
alter table public.sessions enable row level security;
alter table public.reviews enable row level security;
alter table public.opportunities enable row level security;

-- Draft starter policies (minimum access; extend carefully for mentor updates and admin verification).
create policy "profiles_read_authenticated" on public.profiles for select to authenticated using (true);
create policy "profile_owner_insert" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profile_owner_update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "mentor_profiles_read_authenticated" on public.mentor_profiles for select to authenticated using (true);
create policy "mentor_profile_owner_insert" on public.mentor_profiles for insert to authenticated with check (user_id = auth.uid());
create policy "mentor_profile_owner_update" on public.mentor_profiles for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "subjects_read_authenticated" on public.subjects for select to authenticated using (true);
create policy "expertise_read_authenticated" on public.mentor_expertise for select to authenticated using (true);
create policy "expertise_owner_insert" on public.mentor_expertise for insert to authenticated with check (mentor_id = auth.uid());
create policy "expertise_owner_update" on public.mentor_expertise for update to authenticated using (mentor_id = auth.uid()) with check (mentor_id = auth.uid());
create policy "expertise_owner_delete" on public.mentor_expertise for delete to authenticated using (mentor_id = auth.uid());

create policy "request_participant_read" on public.learning_requests for select to authenticated using (learner_id = auth.uid() or mentor_id = auth.uid());
create policy "learner_create_request" on public.learning_requests for insert to authenticated with check (learner_id = auth.uid() and learner_id <> mentor_id);
create policy "learner_cancel_own_request" on public.learning_requests for update to authenticated using (learner_id = auth.uid()) with check (learner_id = auth.uid());
create policy "mentor_update_assigned_request" on public.learning_requests for update to authenticated using (mentor_id = auth.uid()) with check (mentor_id = auth.uid());

create policy "course_participant_read" on public.courses for select to authenticated using (learner_id = auth.uid() or mentor_id = auth.uid());
create policy "mentor_create_course" on public.courses for insert to authenticated with check (mentor_id = auth.uid());
create policy "course_mentor_update" on public.courses for update to authenticated using (mentor_id = auth.uid()) with check (mentor_id = auth.uid());
create policy "module_participant_read" on public.course_modules for select to authenticated using (exists (select 1 from public.courses c where c.id = course_id and (c.learner_id = auth.uid() or c.mentor_id = auth.uid())));
create policy "module_mentor_insert" on public.course_modules for insert to authenticated with check (exists (select 1 from public.courses c where c.id = course_id and c.mentor_id = auth.uid()));
create policy "module_mentor_update" on public.course_modules for update to authenticated using (exists (select 1 from public.courses c where c.id = course_id and c.mentor_id = auth.uid())) with check (exists (select 1 from public.courses c where c.id = course_id and c.mentor_id = auth.uid()));

create policy "progress_participant_read" on public.module_progress for select to authenticated using (learner_id = auth.uid() or exists (select 1 from public.courses c join public.course_modules m on m.course_id = c.id where m.id = module_id and c.mentor_id = auth.uid()));
create policy "learner_upsert_own_progress" on public.module_progress for insert to authenticated with check (learner_id = auth.uid());
create policy "learner_update_own_progress" on public.module_progress for update to authenticated using (learner_id = auth.uid()) with check (learner_id = auth.uid());

create policy "session_participant_read" on public.sessions for select to authenticated using (learner_id = auth.uid() or mentor_id = auth.uid());
create policy "participant_create_session" on public.sessions for insert to authenticated with check (learner_id = auth.uid() or mentor_id = auth.uid());
create policy "mentor_update_session_record" on public.sessions for update to authenticated using (mentor_id = auth.uid()) with check (mentor_id = auth.uid());

create policy "review_read_authenticated" on public.reviews for select to authenticated using (moderation_status = 'published' or learner_id = auth.uid() or mentor_id = auth.uid());
create policy "learner_review_own_session" on public.reviews for insert to authenticated with check (learner_id = auth.uid() and exists (select 1 from public.sessions s where s.id = session_id and s.learner_id = auth.uid() and s.status = 'completed'));

create policy "published_opportunities_read" on public.opportunities for select to authenticated using (status = 'published');

-- IMPORTANT SECURITY NOTES:
-- 1) These starter policies need testing; the request update policies currently let the relevant
--    participant update any request columns. Production should restrict allowed status transitions.
-- 2) Add an admin/staff role model before enabling mentor verification or review moderation.
-- 3) Add triggers for updated_at, profile creation, average rating, and request->session workflows.
-- 4) Never put a Supabase service_role key in browser code.
