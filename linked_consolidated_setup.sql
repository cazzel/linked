-- ============================================================================
-- LINKED — CONSOLIDATED DATABASE SETUP (FRESH PROJECT ONLY)
-- ============================================================================
-- Purpose:
--   One canonical SQL file for a NEW Supabase project. Combines the initial
--   schema and the feature/security setup scripts that were previously kept
--   in separate files.
--
-- IMPORTANT:
--   * DO NOT run this file on your current/persisted LINKED project. It starts
--     by creating types and tables that already exist there.
--   * Use only against a fresh project, or as source documentation in GitHub.
--   * Create/register the intended admin user in Supabase Auth first, then
--     replace GANTI_DENGAN_EMAIL_ADMIN_LINKED below with that exact email.
--   * Never place service_role/secret keys in this file or in frontend code.
--   * All feature setup is wrapped in one transaction. Any SQL error should
--     roll back this setup when executed by a SQL client that supports it.
--
-- Existing LINKED project:
--   Keep using the running database. Upload this file to GitHub as a canonical
--   setup reference; do not run it against the live database.
-- ============================================================================

BEGIN;

-- 01 — Initial schema and draft RLS policies (tightened in later sections)
-- LINKED initial relational schema. Later sections in this file replace the draft policies
-- with the application-specific policies and least-privilege grants used by this MVP.

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


-- ============================================================================
-- 02 — Mentor profile submission and subject catalog
-- Source folded from: linked-mentor-profile-setup.sql
-- ============================================================================
-- LINKED: safely enable mentor profile applications
-- Run this in Supabase SQL Editor after reviewing it.
-- Owners can submit/edit their own application, but cannot self-approve.
-- New mentor applications should wait for admin review by default.
ALTER TABLE public.mentor_profiles
  ALTER COLUMN verification_status SET DEFAULT 'pending';

-- Frontend read access needed to show the subject catalog and a user's own profile.
GRANT SELECT ON TABLE public.subjects TO authenticated;
GRANT SELECT (user_id, verification_status, teaching_bio, teaching_experience,
  availability_notes, online_available, offline_available, is_active, created_at, updated_at)
  ON TABLE public.mentor_profiles TO authenticated;
GRANT SELECT ON TABLE public.mentor_expertise TO authenticated;

-- Remove any broad table-level write grants before applying the narrower grants below.
-- RLS policies will further restrict rows to the authenticated owner.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.mentor_profiles FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.mentor_expertise FROM PUBLIC, anon, authenticated;

-- Limited writes for users applying to become mentors.
GRANT INSERT (user_id, teaching_bio, teaching_experience, availability_notes,
  online_available, offline_available)
  ON TABLE public.mentor_profiles TO authenticated;
GRANT UPDATE (verification_status, teaching_bio, teaching_experience,
  availability_notes, online_available, offline_available)
  ON TABLE public.mentor_profiles TO authenticated;
GRANT INSERT (mentor_id, subject_id, topics)
  ON TABLE public.mentor_expertise TO authenticated;
GRANT UPDATE (mentor_id, subject_id, topics)
  ON TABLE public.mentor_expertise TO authenticated;
GRANT DELETE ON TABLE public.mentor_expertise TO authenticated;

-- Ensure an owner may only create a pending application, never an approved one.
DROP POLICY IF EXISTS "mentor_profile_owner_insert" ON public.mentor_profiles;
CREATE POLICY "mentor_profile_owner_insert"
  ON public.mentor_profiles FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND verification_status = 'pending');

-- Users can update their own non-approved application, but cannot change it to approved.
DROP POLICY IF EXISTS "mentor_profile_owner_update" ON public.mentor_profiles;
CREATE POLICY "mentor_profile_owner_update"
  ON public.mentor_profiles FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND verification_status <> 'approved')
  WITH CHECK (
    user_id = auth.uid()
    AND verification_status IN ('not_submitted', 'pending', 'rejected', 'trial')
  );

-- Pending expertise is visible only to its owner; approved active expertise is public to signed-in users.
DROP POLICY IF EXISTS "expertise_read_authenticated" ON public.mentor_expertise;
CREATE POLICY "expertise_read_authenticated"
  ON public.mentor_expertise FOR SELECT TO authenticated
  USING (
    mentor_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = mentor_expertise.mentor_id
        AND mp.verification_status = 'approved'
        AND mp.is_active = true
    )
  );

DROP POLICY IF EXISTS "expertise_owner_insert" ON public.mentor_expertise;
CREATE POLICY "expertise_owner_insert"
  ON public.mentor_expertise FOR INSERT TO authenticated
  WITH CHECK (
    mentor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid()
        AND mp.verification_status <> 'approved'
    )
  );

DROP POLICY IF EXISTS "expertise_owner_update" ON public.mentor_expertise;
CREATE POLICY "expertise_owner_update"
  ON public.mentor_expertise FOR UPDATE TO authenticated
  USING (
    mentor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid()
        AND mp.verification_status <> 'approved'
    )
  )
  WITH CHECK (
    mentor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid()
        AND mp.verification_status <> 'approved'
    )
  );

DROP POLICY IF EXISTS "expertise_owner_delete" ON public.mentor_expertise;
CREATE POLICY "expertise_owner_delete"
  ON public.mentor_expertise FOR DELETE TO authenticated
  USING (
    mentor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.mentor_profiles mp
      WHERE mp.user_id = auth.uid()
        AND mp.verification_status <> 'approved'
    )
  );

-- Populate a starter subject list; existing names are left untouched.
INSERT INTO public.subjects (name, category) VALUES
  ('Mathematics', 'STEM'),
  ('Statistics & Probability', 'STEM'),
  ('Physics', 'STEM'),
  ('Chemistry', 'STEM'),
  ('Biology', 'STEM'),
  ('Programming Fundamentals', 'Computer Science'),
  ('Python Programming', 'Computer Science'),
  ('C / C++ Programming', 'Computer Science'),
  ('Data Structures & Algorithms', 'Computer Science'),
  ('Artificial Intelligence', 'Computer Science'),
  ('Machine Learning', 'Computer Science'),
  ('Robotics', 'Engineering'),
  ('Data Analysis', 'Computer Science'),
  ('Business Mathematics', 'Business'),
  ('Accounting', 'Business'),
  ('Economics', 'Business'),
  ('Marketing', 'Business'),
  ('Academic Writing', 'Communication'),
  ('English', 'Language'),
  ('Presentation Skills', 'Communication')
ON CONFLICT (name) DO NOTHING;


-- ============================================================================
-- 03 — Learning requests and status transitions
-- Source folded from: linked-learning-requests-setup.sql
-- ============================================================================
-- LINKED: secure browser access for learning_requests
-- Run once in Supabase Dashboard > SQL Editor after mentor profile setup.
-- This only grants the operations used by the LINKED frontend and replaces
-- the broad draft policies for learning_requests with participant-specific rules.
ALTER TABLE public.learning_requests ENABLE ROW LEVEL SECURITY;

-- Remove broad client privileges from the request table, then grant only the
-- columns/operations required by the app. service_role is intentionally untouched.
REVOKE ALL PRIVILEGES ON TABLE public.learning_requests FROM PUBLIC, anon, authenticated;

GRANT SELECT (
  id, learner_id, mentor_id, subject_id, topic, learning_objective,
  current_understanding, learning_type, requested_week, preferred_date,
  preferred_time, duration_minutes, mode, location_or_link,
  additional_notes, status, mentor_response_note, created_at, updated_at
) ON TABLE public.learning_requests TO authenticated;

-- Users may create pending requests, but may not choose their own status.
GRANT INSERT (
  learner_id, mentor_id, subject_id, topic, learning_objective,
  current_understanding, learning_type, requested_week, preferred_date,
  preferred_time, duration_minutes, mode, location_or_link, additional_notes
) ON TABLE public.learning_requests TO authenticated;

-- All status transitions are controlled by RLS policies below.
GRANT UPDATE (status) ON TABLE public.learning_requests TO authenticated;

-- Ensure relation reads used by the request list and validation policies exist.
GRANT SELECT ON TABLE public.subjects, public.mentor_expertise TO authenticated;
GRANT SELECT (id, full_name, study_program, cohort_year)
  ON TABLE public.profiles TO authenticated;
GRANT SELECT (user_id, verification_status, is_active)
  ON TABLE public.mentor_profiles TO authenticated;

-- Remove the broad starter policies created in the initial schema.
DROP POLICY IF EXISTS "request_participant_read" ON public.learning_requests;
DROP POLICY IF EXISTS "learner_create_request" ON public.learning_requests;
DROP POLICY IF EXISTS "learner_cancel_own_request" ON public.learning_requests;
DROP POLICY IF EXISTS "mentor_update_assigned_request" ON public.learning_requests;

-- Only the learner and the specifically selected mentor can read a request.
CREATE POLICY "request_participant_read"
  ON public.learning_requests
  FOR SELECT TO authenticated
  USING (learner_id = (SELECT auth.uid()) OR mentor_id = (SELECT auth.uid()));

-- A learner can request an active, approved mentor only for a subject that
-- mentor actually offers. A request cannot be sent to one's own account.
CREATE POLICY "learner_create_request"
  ON public.learning_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    learner_id = (SELECT auth.uid())
    AND learner_id <> mentor_id
    AND EXISTS (
      SELECT 1
      FROM public.mentor_profiles AS mp
      WHERE mp.user_id = learning_requests.mentor_id
        AND mp.verification_status = 'approved'
        AND mp.is_active = true
    )
    AND EXISTS (
      SELECT 1
      FROM public.mentor_expertise AS me
      WHERE me.mentor_id = learning_requests.mentor_id
        AND me.subject_id = learning_requests.subject_id
    )
  );

-- Learner may only cancel their own still-pending request.
CREATE POLICY "learner_cancel_pending_request"
  ON public.learning_requests
  FOR UPDATE TO authenticated
  USING (
    learner_id = (SELECT auth.uid())
    AND status = 'pending'
  )
  WITH CHECK (
    learner_id = (SELECT auth.uid())
    AND status = 'cancelled'
  );

-- Assigned mentor may accept or reject a pending request.
CREATE POLICY "mentor_respond_pending_request"
  ON public.learning_requests
  FOR UPDATE TO authenticated
  USING (
    mentor_id = (SELECT auth.uid())
    AND status = 'pending'
  )
  WITH CHECK (
    mentor_id = (SELECT auth.uid())
    AND status IN ('confirmed', 'rejected')
  );

-- Assigned mentor may mark a confirmed request as completed.
CREATE POLICY "mentor_complete_confirmed_request"
  ON public.learning_requests
  FOR UPDATE TO authenticated
  USING (
    mentor_id = (SELECT auth.uid())
    AND status = 'confirmed'
  )
  WITH CHECK (
    mentor_id = (SELECT auth.uid())
    AND status = 'completed'
  );


-- ============================================================================
-- 04 — Sessions and request synchronization
-- Source folded from: linked-sessions-setup.sql
-- ============================================================================
-- LINKED: integrate database sessions with learning_requests.
-- Run once in Supabase Dashboard > SQL Editor for the LINKED project.
-- Creates/updates a session when a pending request is accepted, backfills existing
-- confirmed/completed requests, and keeps session completion aligned with requests.
-- All client-visible access is participant-scoped; only mentors can edit session notes.
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Replace broad draft table privileges with the minimum browser operations needed.
REVOKE ALL PRIVILEGES ON TABLE public.sessions FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, learning_request_id, course_id, learner_id, mentor_id, topic,
  starts_at, duration_minutes, mode, location_or_link, status,
  summary, next_steps, created_at
) ON TABLE public.sessions TO authenticated;
GRANT UPDATE (summary, next_steps) ON TABLE public.sessions TO authenticated;

DROP POLICY IF EXISTS "session_participant_read" ON public.sessions;
DROP POLICY IF EXISTS "participant_create_session" ON public.sessions;
DROP POLICY IF EXISTS "mentor_update_session_record" ON public.sessions;
DROP POLICY IF EXISTS "session_participant_read_linked" ON public.sessions;
DROP POLICY IF EXISTS "mentor_update_session_notes_linked" ON public.sessions;

CREATE POLICY "session_participant_read_linked"
  ON public.sessions
  FOR SELECT TO authenticated
  USING (learner_id = (SELECT auth.uid()) OR mentor_id = (SELECT auth.uid()));

CREATE POLICY "mentor_update_session_notes_linked"
  ON public.sessions
  FOR UPDATE TO authenticated
  USING (mentor_id = (SELECT auth.uid()))
  WITH CHECK (mentor_id = (SELECT auth.uid()));

-- A trigger creates a session record when a request moves pending -> confirmed.
CREATE OR REPLACE FUNCTION public.linked_sync_session_from_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status
     AND OLD.status = 'pending'::public.request_status
     AND NEW.status = 'confirmed'::public.request_status THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.sessions s WHERE s.learning_request_id = NEW.id
    ) THEN
      INSERT INTO public.sessions (
        learning_request_id, course_id, learner_id, mentor_id, topic,
        starts_at, duration_minutes, mode, location_or_link, status
      ) VALUES (
        NEW.id,
        NULL,
        NEW.learner_id,
        NEW.mentor_id,
        NEW.topic,
        ((NEW.preferred_date + NEW.preferred_time) AT TIME ZONE 'Asia/Jakarta'),
        NEW.duration_minutes,
        NEW.mode,
        NEW.location_or_link,
        'confirmed'::public.request_status
      );
    END IF;
  ELSIF OLD.status = 'confirmed'::public.request_status
        AND NEW.status = 'completed'::public.request_status THEN
    UPDATE public.sessions
    SET status = 'completed'::public.request_status
    WHERE learning_request_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS linked_sync_session_from_request ON public.learning_requests;
CREATE TRIGGER linked_sync_session_from_request
AFTER UPDATE OF status ON public.learning_requests
FOR EACH ROW
EXECUTE FUNCTION public.linked_sync_session_from_request();

-- Backfill requests accepted before this trigger was installed.
INSERT INTO public.sessions (
  learning_request_id, course_id, learner_id, mentor_id, topic,
  starts_at, duration_minutes, mode, location_or_link, status
)
SELECT
  lr.id,
  NULL,
  lr.learner_id,
  lr.mentor_id,
  lr.topic,
  ((lr.preferred_date + lr.preferred_time) AT TIME ZONE 'Asia/Jakarta'),
  lr.duration_minutes,
  lr.mode,
  lr.location_or_link,
  CASE
    WHEN lr.status IN ('completed'::public.request_status, 'reviewed'::public.request_status)
      THEN 'completed'::public.request_status
    ELSE 'confirmed'::public.request_status
  END
FROM public.learning_requests lr
WHERE lr.status IN (
  'confirmed'::public.request_status,
  'completed'::public.request_status,
  'reviewed'::public.request_status
)
AND NOT EXISTS (
  SELECT 1 FROM public.sessions s WHERE s.learning_request_id = lr.id
);


-- ============================================================================
-- 05 — Full courses and learner progress
-- Source folded from: linked-learning-progress-setup.sql
-- ============================================================================
-- LINKED: Learning Progress integration
-- Run this once in the LINKED project. This migration creates a course and starter modules
-- for an approved Full Course request, then enables learners to sync module progress safely.
-- Authenticated users can read courses/modules only where existing RLS policies allow it.
GRANT SELECT ON public.courses, public.course_modules, public.module_progress TO authenticated;
GRANT INSERT (module_id, learner_id, status, completed_at, updated_at)
  ON public.module_progress TO authenticated;
GRANT UPDATE (module_id, learner_id, status, completed_at, updated_at)
  ON public.module_progress TO authenticated;

ALTER TABLE public.module_progress ENABLE ROW LEVEL SECURITY;

-- Learners can see their own progress; the mentor attached to the course can read it too.
DROP POLICY IF EXISTS "progress_participant_read" ON public.module_progress;
CREATE POLICY "progress_participant_read"
ON public.module_progress
FOR SELECT TO authenticated
USING (
  learner_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.course_modules m
    JOIN public.courses c ON c.id = m.course_id
    WHERE m.id = module_progress.module_id
      AND c.mentor_id = auth.uid()
  )
);

-- A learner can create progress only for modules in their own active course.
DROP POLICY IF EXISTS "learner_upsert_own_progress" ON public.module_progress;
CREATE POLICY "learner_upsert_own_progress"
ON public.module_progress
FOR INSERT TO authenticated
WITH CHECK (
  learner_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.course_modules m
    JOIN public.courses c ON c.id = m.course_id
    WHERE m.id = module_progress.module_id
      AND c.learner_id = auth.uid()
      AND c.is_active = true
  )
);

DROP POLICY IF EXISTS "learner_update_own_progress" ON public.module_progress;
CREATE POLICY "learner_update_own_progress"
ON public.module_progress
FOR UPDATE TO authenticated
USING (
  learner_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.course_modules m
    JOIN public.courses c ON c.id = m.course_id
    WHERE m.id = module_progress.module_id
      AND c.learner_id = auth.uid()
      AND c.is_active = true
  )
)
WITH CHECK (
  learner_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.course_modules m
    JOIN public.courses c ON c.id = m.course_id
    WHERE m.id = module_progress.module_id
      AND c.learner_id = auth.uid()
      AND c.is_active = true
  )
);

-- This helper is called by a trigger and during backfill. It does not accept data from the browser.
CREATE OR REPLACE FUNCTION public.linked_ensure_course_for_request(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  req public.learning_requests%ROWTYPE;
  course_uuid uuid;
BEGIN
  SELECT * INTO req
  FROM public.learning_requests
  WHERE id = p_request_id;

  IF NOT FOUND
     OR req.learning_type <> 'full_course'
     OR req.status NOT IN ('confirmed', 'completed', 'reviewed') THEN
    RETURN;
  END IF;

  SELECT c.id INTO course_uuid
  FROM public.courses c
  WHERE c.learning_request_id = req.id
  ORDER BY c.created_at ASC
  LIMIT 1;

  IF course_uuid IS NULL THEN
    INSERT INTO public.courses (
      learning_request_id, learner_id, mentor_id, subject_id,
      title, learning_objective, is_active
    ) VALUES (
      req.id, req.learner_id, req.mentor_id, req.subject_id,
      left(req.topic || ' — Full Course', 240), req.learning_objective, true
    )
    RETURNING id INTO course_uuid;
  END IF;

  -- Preserve mentor-authored modules if any already exist. Otherwise add a starter outline.
  IF NOT EXISTS (
    SELECT 1 FROM public.course_modules m WHERE m.course_id = course_uuid
  ) THEN
    INSERT INTO public.course_modules (course_id, sequence_no, title, topic)
    VALUES
      (course_uuid, 1, 'Tujuan belajar dan pemetaan kemampuan awal', req.topic),
      (course_uuid, 2, left('Konsep dasar: ' || req.topic, 180), req.topic),
      (course_uuid, 3, left('Pendalaman materi: ' || req.topic, 180), req.learning_objective),
      (course_uuid, 4, 'Latihan terbimbing', req.topic),
      (course_uuid, 5, 'Evaluasi dan langkah belajar berikutnya', req.learning_objective);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.linked_on_full_course_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF OLD.status = 'pending'
     AND NEW.status = 'confirmed'
     AND NEW.learning_type = 'full_course' THEN
    PERFORM public.linked_ensure_course_for_request(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS linked_create_course_after_request_confirmed
  ON public.learning_requests;
CREATE TRIGGER linked_create_course_after_request_confirmed
AFTER UPDATE OF status ON public.learning_requests
FOR EACH ROW
EXECUTE FUNCTION public.linked_on_full_course_confirmed();

-- Backfill Full Course requests that were already accepted before this migration.
DO $$
DECLARE
  request_row record;
BEGIN
  FOR request_row IN
    SELECT id
    FROM public.learning_requests
    WHERE learning_type = 'full_course'
      AND status IN ('confirmed', 'completed', 'reviewed')
  LOOP
    PERFORM public.linked_ensure_course_for_request(request_row.id);
  END LOOP;
END;
$$;

-- Prevent direct API invocation of internal helpers; triggers still execute as the function owner.
REVOKE ALL ON FUNCTION public.linked_ensure_course_for_request(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.linked_on_full_course_confirmed() FROM PUBLIC, anon, authenticated;


-- ============================================================================
-- 06 — Reviews and rating moderation
-- Source folded from: linked-reviews-setup.sql
-- ============================================================================
-- LINKED: connect session reviews and mentor ratings to Supabase.
-- Run ONLY in the LINKED Supabase project after sessions integration has succeeded.
-- MVP decision: valid reviews from learners for their own completed sessions are published immediately.
-- Add an admin moderation workflow before opening this to a larger public audience.
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Minimal client privileges. Do not allow clients to change moderation_status,
-- session_id, learner_id, or mentor_id after submission.
REVOKE ALL PRIVILEGES ON TABLE public.reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, session_id, learner_id, mentor_id, rating, comment, moderation_status, created_at
) ON TABLE public.reviews TO authenticated;
GRANT INSERT (
  session_id, learner_id, mentor_id, rating, comment
) ON TABLE public.reviews TO authenticated;

-- For this MVP, new valid reviews appear immediately. Users cannot select the
-- moderation_status column during INSERT because it is omitted from INSERT grants.
ALTER TABLE public.reviews
  ALTER COLUMN moderation_status SET DEFAULT 'published';

DROP POLICY IF EXISTS "review_read_authenticated" ON public.reviews;
DROP POLICY IF EXISTS "learner_review_own_session" ON public.reviews;
DROP POLICY IF EXISTS "learner_create_review_for_completed_session" ON public.reviews;

-- Authenticated users can read published reviews. Learner and mentor can also
-- read their own session review even if it is not published in a future workflow.
CREATE POLICY "review_read_authenticated"
  ON public.reviews
  FOR SELECT TO authenticated
  USING (
    moderation_status = 'published'
    OR learner_id = (SELECT auth.uid())
    OR mentor_id = (SELECT auth.uid())
  );

-- Only the learner assigned to a completed session may review it; mentor_id must
-- match the real session. The unique(session_id) constraint prevents duplicate reviews.
CREATE POLICY "learner_create_review_for_completed_session"
  ON public.reviews
  FOR INSERT TO authenticated
  WITH CHECK (
    learner_id = (SELECT auth.uid())
    AND learner_id <> mentor_id
    AND EXISTS (
      SELECT 1
      FROM public.sessions AS s
      WHERE s.id = reviews.session_id
        AND s.learner_id = (SELECT auth.uid())
        AND s.mentor_id = reviews.mentor_id
        AND s.status = 'completed'::public.request_status
    )
  );


-- ============================================================================
-- 07 — Admin access and moderation permissions
-- Source folded from: linked-admin-setup.sql
-- ============================================================================
-- LINKED: Admin dashboard, mentor approval, and review moderation.
-- IMPORTANT: Before running this script, replace the email in the DO block at the bottom
-- with the exact email of an existing LINKED account in THIS project.
-- Run only in the intended LINKED project. This script does not create an admin account;
-- it assigns admin access to an account that has already registered.
-- Keep the security-definer helper outside the API-exposed public schema.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

-- A minimal allow-list. Regular users cannot insert, update, or delete admin assignments.
CREATE TABLE IF NOT EXISTS public.linked_admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.linked_admin_users ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.linked_admin_users FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.linked_admin_users TO authenticated;

DROP POLICY IF EXISTS linked_admin_read_own_assignment ON public.linked_admin_users;
CREATE POLICY linked_admin_read_own_assignment
  ON public.linked_admin_users
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Safe helper for policies. The function checks the private allow-list and does not accept a user id.
CREATE OR REPLACE FUNCTION private.linked_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.linked_admin_users AS admin_row
    WHERE admin_row.user_id = (SELECT auth.uid())
  );
$$;
REVOKE ALL ON FUNCTION private.linked_is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.linked_is_admin() TO authenticated;

-- Admin dashboard needs read access to pending and approved mentor applications and their subjects.
ALTER TABLE public.mentor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_expertise ENABLE ROW LEVEL SECURITY;
GRANT SELECT (
  user_id, verification_status, teaching_bio, teaching_experience,
  availability_notes, online_available, offline_available, is_active,
  created_at, updated_at
) ON TABLE public.mentor_profiles TO authenticated;
GRANT SELECT ON TABLE public.mentor_expertise TO authenticated;

DROP POLICY IF EXISTS linked_admin_read_all_mentor_profiles ON public.mentor_profiles;
CREATE POLICY linked_admin_read_all_mentor_profiles
  ON public.mentor_profiles
  FOR SELECT TO authenticated
  USING ((SELECT private.linked_is_admin()));

-- Initial admin policy excludes self-review; section 11 below applies the configured pilot self-review policy.
DROP POLICY IF EXISTS linked_admin_update_mentor_profiles ON public.mentor_profiles;
CREATE POLICY linked_admin_update_mentor_profiles
  ON public.mentor_profiles
  FOR UPDATE TO authenticated
  USING ((SELECT private.linked_is_admin()) AND user_id <> (SELECT auth.uid()))
  WITH CHECK ((SELECT private.linked_is_admin()) AND user_id <> (SELECT auth.uid()));
GRANT UPDATE (verification_status, is_active, updated_at)
  ON TABLE public.mentor_profiles TO authenticated;

DROP POLICY IF EXISTS linked_admin_read_all_mentor_expertise ON public.mentor_expertise;
CREATE POLICY linked_admin_read_all_mentor_expertise
  ON public.mentor_expertise
  FOR SELECT TO authenticated
  USING ((SELECT private.linked_is_admin()));

-- Admins can view all reviews and change only the moderation status.
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
GRANT SELECT (
  id, session_id, learner_id, mentor_id, rating, comment, moderation_status, created_at
) ON TABLE public.reviews TO authenticated;
REVOKE UPDATE ON TABLE public.reviews FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (moderation_status) ON TABLE public.reviews FROM PUBLIC, anon, authenticated;
GRANT UPDATE (moderation_status) ON TABLE public.reviews TO authenticated;

DROP POLICY IF EXISTS linked_admin_read_all_reviews ON public.reviews;
CREATE POLICY linked_admin_read_all_reviews
  ON public.reviews
  FOR SELECT TO authenticated
  USING ((SELECT private.linked_is_admin()));

DROP POLICY IF EXISTS linked_admin_moderate_reviews ON public.reviews;
CREATE POLICY linked_admin_moderate_reviews
  ON public.reviews
  FOR UPDATE TO authenticated
  USING ((SELECT private.linked_is_admin()) AND learner_id <> (SELECT auth.uid()))
  WITH CHECK ((SELECT private.linked_is_admin()) AND learner_id <> (SELECT auth.uid()));

-- Future reviews wait for approval; existing published reviews remain published.
ALTER TABLE public.reviews
  ALTER COLUMN moderation_status SET DEFAULT 'pending';

-- Assign administrator rights by the email of an already registered LINKED account.
-- Replace the value below before executing this file.
DO $$
DECLARE
  admin_email text := lower('GANTI_DENGAN_EMAIL_ADMIN_LINKED');
  admin_user_id uuid;
BEGIN
  IF admin_email = '' OR admin_email = 'ganti_dengan_email_admin_linked' THEN
    RAISE EXCEPTION 'Ganti GANTI_DENGAN_EMAIL_ADMIN_LINKED dengan email akun admin yang sudah terdaftar di Supabase Auth proyek ini.';
  END IF;

  SELECT u.id
    INTO admin_user_id
    FROM auth.users AS u
    WHERE lower(u.email) = admin_email
    LIMIT 1;

  IF admin_user_id IS NULL THEN
    RAISE EXCEPTION 'Akun dengan email tersebut belum ditemukan di proyek ini. Pastikan email benar dan akun sudah terdaftar.';
  END IF;

  INSERT INTO public.linked_admin_users (user_id)
  VALUES (admin_user_id)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;


-- ============================================================================
-- 08 — Opportunities and in-app notifications
-- Source folded from: linked-platform-features-setup.sql
-- ============================================================================
-- LINKED: in-app notifications + Opportunities management
-- Run once in the intended LINKED project after linked-admin-setup.sql.
-- Idempotent: policies and triggers are replaced safely; existing opportunity/review data is preserved.
-- Admin helper is provisioned by linked-admin-setup.sql.
DO $$
BEGIN
  IF to_regprocedure('private.linked_is_admin()') IS NULL THEN
    RAISE EXCEPTION 'Jalankan linked-admin-setup.sql terlebih dahulu pada proyek LINKED yang benar.';
  END IF;
END;
$$;

-- 1) Opportunities: public users can read published items; admins can manage drafts and status.
GRANT SELECT, INSERT, UPDATE ON TABLE public.opportunities TO authenticated;
ALTER TABLE public.opportunities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS linked_admin_read_all_opportunities ON public.opportunities;
CREATE POLICY linked_admin_read_all_opportunities
  ON public.opportunities FOR SELECT TO authenticated
  USING ((SELECT private.linked_is_admin()));
DROP POLICY IF EXISTS linked_admin_insert_opportunities ON public.opportunities;
CREATE POLICY linked_admin_insert_opportunities
  ON public.opportunities FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.linked_is_admin()) AND created_by = (SELECT auth.uid()));
DROP POLICY IF EXISTS linked_admin_update_opportunities ON public.opportunities;
CREATE POLICY linked_admin_update_opportunities
  ON public.opportunities FOR UPDATE TO authenticated
  USING ((SELECT private.linked_is_admin()))
  WITH CHECK ((SELECT private.linked_is_admin()));

-- 2) Private notification store. Clients can only read their own notifications and mark them read.
CREATE TABLE IF NOT EXISTS public.linked_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  target_page text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS linked_notifications_user_created_idx
  ON public.linked_notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS linked_notifications_user_unread_idx
  ON public.linked_notifications (user_id, created_at DESC) WHERE read_at IS NULL;
ALTER TABLE public.linked_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.linked_notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.linked_notifications TO authenticated;
GRANT UPDATE (read_at) ON TABLE public.linked_notifications TO authenticated;
DROP POLICY IF EXISTS linked_notifications_read_own ON public.linked_notifications;
CREATE POLICY linked_notifications_read_own
  ON public.linked_notifications FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS linked_notifications_mark_own_read ON public.linked_notifications;
CREATE POLICY linked_notifications_mark_own_read
  ON public.linked_notifications FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- All inserts happen through trigger-only SECURITY DEFINER functions, not from browser clients.
CREATE OR REPLACE FUNCTION private.linked_create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_target_page text DEFAULT NULL,
  p_entity_id uuid DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_user_id IS NULL OR p_title IS NULL OR p_body IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO public.linked_notifications
    (user_id, notification_type, title, body, target_page, entity_id)
  VALUES
    (p_user_id, p_type, left(p_title, 160), left(p_body, 800), p_target_page, p_entity_id);
END;
$$;
REVOKE ALL ON FUNCTION private.linked_create_notification(uuid, text, text, text, text, uuid) FROM PUBLIC, anon, authenticated;

-- New learning request -> notify selected mentor.
CREATE OR REPLACE FUNCTION private.notify_learning_request_created()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE learner_name text;
BEGIN
  SELECT p.full_name INTO learner_name FROM public.profiles p WHERE p.id = NEW.learner_id;
  PERFORM private.linked_create_notification(
    NEW.mentor_id, 'learning_request_new', 'Permintaan belajar baru',
    coalesce(learner_name, 'Seorang learner') || ' mengirim permintaan untuk topik: ' || NEW.topic,
    'requests', NEW.id
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_learning_request_created ON public.learning_requests;
CREATE TRIGGER linked_notify_learning_request_created
  AFTER INSERT ON public.learning_requests
  FOR EACH ROW EXECUTE FUNCTION private.notify_learning_request_created();

-- Learning request status changes -> notify the other participant(s).
CREATE OR REPLACE FUNCTION private.notify_learning_request_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE learner_name text; mentor_name text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  SELECT p.full_name INTO learner_name FROM public.profiles p WHERE p.id = NEW.learner_id;
  SELECT p.full_name INTO mentor_name FROM public.profiles p WHERE p.id = NEW.mentor_id;
  IF NEW.status = 'confirmed' THEN
    PERFORM private.linked_create_notification(NEW.learner_id, 'request_confirmed', 'Permintaan belajar disetujui', coalesce(mentor_name, 'Mentor pilihanmu') || ' telah menyetujui permintaan belajarmu.', 'requests', NEW.id);
  ELSIF NEW.status = 'rejected' THEN
    PERFORM private.linked_create_notification(NEW.learner_id, 'request_rejected', 'Permintaan belajar ditolak', coalesce(mentor_name, 'Mentor pilihanmu') || ' belum dapat menerima permintaan ini.', 'requests', NEW.id);
  ELSIF NEW.status = 'cancelled' THEN
    PERFORM private.linked_create_notification(NEW.mentor_id, 'request_cancelled', 'Permintaan belajar dibatalkan', coalesce(learner_name, 'Learner') || ' membatalkan permintaan belajar.', 'requests', NEW.id);
  ELSIF NEW.status = 'completed' THEN
    PERFORM private.linked_create_notification(NEW.learner_id, 'session_completed', 'Sesi belajar selesai', 'Sesi belajarmu ditandai selesai. Kamu dapat melihat catatan dan memberikan ulasan jika belum.', 'requests', NEW.id);
    PERFORM private.linked_create_notification(NEW.mentor_id, 'session_completed', 'Sesi belajar selesai', 'Sesi belajar yang kamu bimbing telah ditandai selesai.', 'requests', NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_learning_request_status ON public.learning_requests;
CREATE TRIGGER linked_notify_learning_request_status
  AFTER UPDATE OF status ON public.learning_requests
  FOR EACH ROW EXECUTE FUNCTION private.notify_learning_request_status();

-- Mentor application status -> notify applicant; new pending application -> notify admins.
CREATE OR REPLACE FUNCTION private.notify_mentor_profile_changes()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE admin_row record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.verification_status = 'pending' THEN
      FOR admin_row IN SELECT a.user_id FROM public.linked_admin_users a LOOP
        PERFORM private.linked_create_notification(admin_row.user_id, 'mentor_application_new', 'Pendaftaran mentor baru', 'Ada profil mentor baru yang menunggu tinjauan.', 'admin', NEW.user_id);
      END LOOP;
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
    IF NEW.verification_status = 'approved' THEN
      PERFORM private.linked_create_notification(NEW.user_id, 'mentor_approved', 'Profil mentor disetujui', 'Profilmu sudah disetujui dan dapat tampil di direktori selama masih aktif.', 'mentor-tools', NEW.user_id);
    ELSIF NEW.verification_status = 'rejected' THEN
      PERFORM private.linked_create_notification(NEW.user_id, 'mentor_rejected', 'Profil mentor perlu diperbaiki', 'Profil mentor belum disetujui. Periksa kembali informasi profil sebelum mengajukan ulang.', 'mentor-tools', NEW.user_id);
    ELSIF NEW.verification_status = 'pending' THEN
      FOR admin_row IN SELECT a.user_id FROM public.linked_admin_users a LOOP
        PERFORM private.linked_create_notification(admin_row.user_id, 'mentor_application_new', 'Pendaftaran mentor menunggu tinjauan', 'Ada profil mentor yang perlu diperiksa.', 'admin', NEW.user_id);
      END LOOP;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_mentor_profile_changes ON public.mentor_profiles;
CREATE TRIGGER linked_notify_mentor_profile_changes
  AFTER INSERT OR UPDATE ON public.mentor_profiles
  FOR EACH ROW EXECUTE FUNCTION private.notify_mentor_profile_changes();

-- Session notes -> notify learner when mentor adds or changes the shared notes.
CREATE OR REPLACE FUNCTION private.notify_session_notes_changed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.summary IS DISTINCT FROM OLD.summary OR NEW.next_steps IS DISTINCT FROM OLD.next_steps THEN
    PERFORM private.linked_create_notification(NEW.learner_id, 'session_notes_updated', 'Catatan sesi diperbarui', 'Mentor memperbarui ringkasan sesi atau langkah belajar berikutnya.', 'requests', NEW.learning_request_id);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_session_notes_changed ON public.sessions;
CREATE TRIGGER linked_notify_session_notes_changed
  AFTER UPDATE OF summary, next_steps ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION private.notify_session_notes_changed();

-- New review -> inform mentor that a review is waiting for moderation.
CREATE OR REPLACE FUNCTION private.notify_review_submitted()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM private.linked_create_notification(NEW.mentor_id, 'review_submitted', 'Ulasan baru diterima', 'Learner memberikan ulasan untuk sesi yang telah selesai. Ulasan akan tampil setelah pemeriksaan.', 'mentor-tools', NEW.id);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_review_submitted ON public.reviews;
CREATE TRIGGER linked_notify_review_submitted
  AFTER INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION private.notify_review_submitted();

-- When admin publishes/hides a review, notify its author only when it becomes published.
CREATE OR REPLACE FUNCTION private.notify_review_moderation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.moderation_status = 'published' AND OLD.moderation_status IS DISTINCT FROM NEW.moderation_status THEN
    PERFORM private.linked_create_notification(NEW.learner_id, 'review_published', 'Ulasan berhasil ditampilkan', 'Ulasanmu telah melalui pemeriksaan dan sekarang dapat dilihat pada profil mentor.', 'mentors', NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_review_moderation ON public.reviews;
CREATE TRIGGER linked_notify_review_moderation
  AFTER UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION private.notify_review_moderation();

-- When a Full Course is provisioned, tell the learner that the learning plan is available.
CREATE OR REPLACE FUNCTION private.notify_course_created()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM private.linked_create_notification(NEW.learner_id, 'course_created', 'Learning plan tersedia', 'Rencana belajar dan modul awal sudah tersedia di My learning.', 'learning', NEW.id);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_course_created ON public.courses;
CREATE TRIGGER linked_notify_course_created
  AFTER INSERT ON public.courses
  FOR EACH ROW EXECUTE FUNCTION private.notify_course_created();

-- Publish an opportunity -> notify all registered users except the publisher.
CREATE OR REPLACE FUNCTION private.notify_opportunity_published()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE recipient record; should_notify boolean := false;
BEGIN
  IF TG_OP = 'INSERT' THEN
    should_notify := NEW.status = 'published';
  ELSE
    should_notify := NEW.status = 'published' AND OLD.status IS DISTINCT FROM 'published';
  END IF;
  IF should_notify THEN
    FOR recipient IN SELECT u.id FROM auth.users u WHERE NEW.created_by IS NULL OR u.id <> NEW.created_by LOOP
      PERFORM private.linked_create_notification(recipient.id, 'opportunity_published', 'Kesempatan baru tersedia', NEW.title || ' kini tersedia di Opportunities.', 'opportunities', NEW.id);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS linked_notify_opportunity_published ON public.opportunities;
CREATE TRIGGER linked_notify_opportunity_published
  AFTER INSERT OR UPDATE ON public.opportunities
  FOR EACH ROW EXECUTE FUNCTION private.notify_opportunity_published();


-- ============================================================================
-- 09 — Support center and user tickets
-- Source folded from: linked-pilot-support-setup.sql
-- ============================================================================
-- LINKED Pilot Support Center
-- Run in the intended LINKED project after the Admin setup has been applied.
-- This script is additive: it creates a support ticket table and policies only.
DO $$
BEGIN
  IF to_regprocedure('private.linked_is_admin()') IS NULL THEN
    RAISE EXCEPTION 'Konfigurasi pengelola belum tersedia. Jalankan setup Admin LINKED terlebih dahulu.';
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('bug', 'account', 'mentor', 'learning', 'opportunity', 'safety', 'other')),
  subject text NOT NULL CHECK (char_length(btrim(subject)) BETWEEN 4 AND 120),
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 15 AND 2000),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  admin_response text CHECK (admin_response IS NULL OR char_length(admin_response) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_tickets_user_created_idx
  ON public.support_tickets (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS support_tickets_status_created_idx
  ON public.support_tickets (status, created_at DESC);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.support_tickets FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, user_id, category, subject, description, status,
  admin_response, created_at, updated_at
) ON TABLE public.support_tickets TO authenticated;
GRANT INSERT (user_id, category, subject, description)
  ON TABLE public.support_tickets TO authenticated;
GRANT UPDATE (status, admin_response, updated_at)
  ON TABLE public.support_tickets TO authenticated;

DROP POLICY IF EXISTS support_tickets_read_own_or_admin ON public.support_tickets;
CREATE POLICY support_tickets_read_own_or_admin
  ON public.support_tickets
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT private.linked_is_admin()));

DROP POLICY IF EXISTS support_tickets_insert_own ON public.support_tickets;
CREATE POLICY support_tickets_insert_own
  ON public.support_tickets
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND status = 'open'
    AND admin_response IS NULL
  );

DROP POLICY IF EXISTS support_tickets_update_admin ON public.support_tickets;
CREATE POLICY support_tickets_update_admin
  ON public.support_tickets
  FOR UPDATE TO authenticated
  USING ((SELECT private.linked_is_admin()))
  WITH CHECK ((SELECT private.linked_is_admin()));


-- ============================================================================
-- 10 — Least-privilege grants and function hardening
-- Source folded from: linked-security-hardening.sql
-- ============================================================================
-- LINKED MVP security hardening
-- Run ONLY in the correct LINKED project, after the existing setup scripts.
-- This migration tightens browser grants while preserving the operations used by index.html.
-- It does not delete application data or alter user-facing UI.
DO $$
DECLARE
  missing_objects text[] := ARRAY[]::text[];
  item text;
BEGIN
  FOREACH item IN ARRAY ARRAY[
    'public.profiles',
    'public.mentor_profiles',
    'public.mentor_expertise',
    'public.subjects',
    'public.learning_requests',
    'public.courses',
    'public.course_modules',
    'public.module_progress',
    'public.sessions',
    'public.reviews',
    'public.opportunities',
    'public.linked_admin_users',
    'public.linked_notifications'
  ] LOOP
    IF to_regclass(item) IS NULL THEN
      missing_objects := array_append(missing_objects, item);
    END IF;
  END LOOP;

  IF cardinality(missing_objects) > 0 THEN
    RAISE EXCEPTION 'Required LINKED tables are missing: %. Confirm the correct project and run the required setup scripts first.', array_to_string(missing_objects, ', ');
  END IF;

  IF to_regprocedure('private.linked_is_admin()') IS NULL
     OR to_regprocedure('public.linked_ensure_course_for_request(uuid)') IS NULL
     OR to_regprocedure('public.linked_on_full_course_confirmed()') IS NULL
     OR to_regprocedure('public.linked_sync_session_from_request()') IS NULL THEN
    RAISE EXCEPTION 'Required LINKED helper functions are missing. Run the matching admin, learning-progress, and sessions setup scripts first.';
  END IF;
END;
$$;

-- Explicit RLS baseline for every application table used by the browser.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentor_expertise ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.module_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linked_admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linked_notifications ENABLE ROW LEVEL SECURITY;

-- PROFILES: only expose non-sensitive profile fields to signed-in users; no browser-side profile edits yet.
REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
REVOKE SELECT (student_id) ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, full_name, study_program, cohort_year, bio, created_at, updated_at)
  ON TABLE public.profiles TO authenticated;
GRANT INSERT (id, full_name, study_program, cohort_year)
  ON TABLE public.profiles TO authenticated;

-- MENTOR PROFILES: owners can submit/edit their application, admins can approve and activate.
REVOKE ALL PRIVILEGES ON TABLE public.mentor_profiles FROM PUBLIC, anon, authenticated;
REVOKE SELECT (verification_notes) ON TABLE public.mentor_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT (user_id, verification_status, teaching_bio, teaching_experience,
  availability_notes, online_available, offline_available, is_active, created_at, updated_at)
  ON TABLE public.mentor_profiles TO authenticated;
GRANT INSERT (user_id, teaching_bio, teaching_experience, availability_notes,
  online_available, offline_available)
  ON TABLE public.mentor_profiles TO authenticated;
GRANT UPDATE (verification_status, teaching_bio, teaching_experience,
  availability_notes, online_available, offline_available, is_active, updated_at)
  ON TABLE public.mentor_profiles TO authenticated;

-- MENTOR EXPERTISE: only fields required by the profile form; RLS restricts owner/admin visibility and edits.
REVOKE ALL PRIVILEGES ON TABLE public.mentor_expertise FROM PUBLIC, anon, authenticated;
REVOKE SELECT (evidence_note) ON TABLE public.mentor_expertise FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, mentor_id, subject_id, topics, created_at)
  ON TABLE public.mentor_expertise TO authenticated;
GRANT INSERT (mentor_id, subject_id, topics)
  ON TABLE public.mentor_expertise TO authenticated;
GRANT UPDATE (mentor_id, subject_id, topics)
  ON TABLE public.mentor_expertise TO authenticated;
GRANT DELETE ON TABLE public.mentor_expertise TO authenticated;

-- SUBJECT CATALOG: read-only through the browser.
REVOKE ALL PRIVILEGES ON TABLE public.subjects FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.subjects TO authenticated;

-- LEARNING REQUESTS: minimum columns required for submission, participant views, and allowed status transitions.
REVOKE ALL PRIVILEGES ON TABLE public.learning_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, learner_id, mentor_id, subject_id, topic, learning_objective,
  current_understanding, learning_type, requested_week, preferred_date,
  preferred_time, duration_minutes, mode, location_or_link,
  additional_notes, status, mentor_response_note, created_at, updated_at
) ON TABLE public.learning_requests TO authenticated;
GRANT INSERT (
  learner_id, mentor_id, subject_id, topic, learning_objective,
  current_understanding, learning_type, requested_week, preferred_date,
  preferred_time, duration_minutes, mode, location_or_link, additional_notes
) ON TABLE public.learning_requests TO authenticated;
GRANT UPDATE (status) ON TABLE public.learning_requests TO authenticated;

-- COURSES AND MODULES: browser users can read participant-scoped data; server-side triggers create course structure.
REVOKE ALL PRIVILEGES ON TABLE public.courses FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.courses TO authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.course_modules FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.course_modules TO authenticated;

-- MODULE PROGRESS: learner upsert needs the conflict key and value columns. RLS prevents changing another learner's rows.
REVOKE ALL PRIVILEGES ON TABLE public.module_progress FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.module_progress TO authenticated;
GRANT INSERT (module_id, learner_id, status, completed_at, updated_at)
  ON TABLE public.module_progress TO authenticated;
GRANT UPDATE (module_id, learner_id, status, completed_at, updated_at)
  ON TABLE public.module_progress TO authenticated;

-- SESSIONS: read by participants; the mentor can edit only the shared session notes.
REVOKE ALL PRIVILEGES ON TABLE public.sessions FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, learning_request_id, course_id, learner_id, mentor_id, topic,
  starts_at, duration_minutes, mode, location_or_link, status,
  summary, next_steps, created_at
) ON TABLE public.sessions TO authenticated;
GRANT UPDATE (summary, next_steps) ON TABLE public.sessions TO authenticated;

-- REVIEWS: learners can submit; admins can change only moderation_status.
REVOKE ALL PRIVILEGES ON TABLE public.reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, session_id, learner_id, mentor_id, rating, comment, moderation_status, created_at)
  ON TABLE public.reviews TO authenticated;
GRANT INSERT (session_id, learner_id, mentor_id, rating, comment)
  ON TABLE public.reviews TO authenticated;
GRANT UPDATE (moderation_status) ON TABLE public.reviews TO authenticated;

-- OPPORTUNITIES: signed-in users can read; RLS admin policies gate insert/update.
REVOKE ALL PRIVILEGES ON TABLE public.opportunities FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, title, organizer, category, description, registration_url,
  starts_at, ends_at, tags, status, created_by, created_at)
  ON TABLE public.opportunities TO authenticated;
GRANT INSERT (title, organizer, category, description, registration_url,
  starts_at, ends_at, tags, status, created_by)
  ON TABLE public.opportunities TO authenticated;
GRANT UPDATE (title, organizer, category, description, registration_url,
  starts_at, ends_at, tags, status)
  ON TABLE public.opportunities TO authenticated;

-- ADMIN ASSIGNMENTS: only allow checking the current user's own assignment; no browser writes.
REVOKE ALL PRIVILEGES ON TABLE public.linked_admin_users FROM PUBLIC, anon, authenticated;
GRANT SELECT (user_id) ON TABLE public.linked_admin_users TO authenticated;

-- NOTIFICATIONS: users can read their own and update only read_at; inserts are trigger-only.
REVOKE ALL PRIVILEGES ON TABLE public.linked_notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.linked_notifications TO authenticated;
GRANT UPDATE (read_at) ON TABLE public.linked_notifications TO authenticated;

-- Tighten helper function execution grants. Existing triggers continue calling their configured trigger functions.
REVOKE EXECUTE ON FUNCTION private.linked_create_notification(uuid, text, text, text, text, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_learning_request_created() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_learning_request_status() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_mentor_profile_changes() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_session_notes_changed() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_review_submitted() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_review_moderation() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_course_created() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.notify_opportunity_published() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.linked_ensure_course_for_request(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.linked_on_full_course_confirmed() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.linked_sync_session_from_request() FROM PUBLIC, anon, authenticated;

-- Restore the one helper needed by authenticated RLS policies.
GRANT USAGE ON SCHEMA private TO authenticated;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.linked_is_admin() TO authenticated;

-- Use a pinned empty search_path on privileged trigger helpers; all referenced app objects are schema-qualified.
ALTER FUNCTION public.linked_ensure_course_for_request(uuid) SET search_path = '';
ALTER FUNCTION public.linked_on_full_course_confirmed() SET search_path = '';
ALTER FUNCTION public.linked_sync_session_from_request() SET search_path = '';

-- Future-proofing: newly created public objects should not be API-accessible until explicitly granted.
-- These defaults affect future objects created by postgres; existing object grants above are unchanged.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;
-- Function EXECUTE is granted to PUBLIC globally by PostgreSQL unless this default is revoked globally.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;


-- ============================================================================
-- 11 — Admin can review own mentor profile (pilot requirement)
-- Source folded from: linked-admin-allow-self-review.sql
-- ============================================================================
-- LINKED: allow the configured admin to review their own mentor profile when needed.
-- This keeps the action limited to the admin account; it does not grant approval rights to regular users.
DROP POLICY IF EXISTS linked_admin_update_mentor_profiles ON public.mentor_profiles;
CREATE POLICY linked_admin_update_mentor_profiles
  ON public.mentor_profiles
  FOR UPDATE TO authenticated
  USING ((SELECT private.linked_is_admin()))
  WITH CHECK ((SELECT private.linked_is_admin()));

GRANT UPDATE (verification_status, is_active, updated_at)
  ON TABLE public.mentor_profiles TO authenticated;


-- ============================================================================
-- 12 — Secure mentor profile resubmission
-- Source folded from: linked-mentor-profile-edit-setup.sql
-- ============================================================================
-- LINKED: safely resubmit an approved mentor profile for review.
-- Run this in the existing LINKED project after the Admin and security-hardening setup.
-- This migration does not grant owners permission to approve or reactivate their own profile.
DO $guard$
BEGIN
  IF to_regclass('public.mentor_profiles') IS NULL
     OR to_regclass('public.mentor_expertise') IS NULL
     OR to_regclass('public.subjects') IS NULL THEN
    RAISE EXCEPTION 'Required mentor tables are missing. Confirm you are using the correct LINKED project and have run the mentor setup first.';
  END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION public.linked_resubmit_approved_mentor_profile(
  p_teaching_bio text,
  p_teaching_experience text,
  p_availability_notes text,
  p_online_available boolean,
  p_offline_available boolean,
  p_expertise jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_status public.mentor_verification_status;
  v_item jsonb;
  v_subject_id uuid;
  v_topics text[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in is required to submit mentor profile changes.';
  END IF;

  IF nullif(btrim(coalesce(p_teaching_bio, '')), '') IS NULL
     OR char_length(p_teaching_bio) > 1200 THEN
    RAISE EXCEPTION 'Provide a mentor bio of 1–1200 characters.';
  END IF;
  IF char_length(coalesce(p_teaching_experience, '')) > 500 THEN
    RAISE EXCEPTION 'Teaching experience must be 500 characters or fewer.';
  END IF;
  IF char_length(coalesce(p_availability_notes, '')) > 300 THEN
    RAISE EXCEPTION 'Availability notes must be 300 characters or fewer.';
  END IF;
  IF p_online_available IS DISTINCT FROM true
     AND p_offline_available IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'At least one learning mode must be selected.';
  END IF;

  IF p_expertise IS NULL OR jsonb_typeof(p_expertise) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Select at least one subject and provide its topics.';
  END IF;
  IF jsonb_array_length(p_expertise) < 1 OR jsonb_array_length(p_expertise) > 20 THEN
    RAISE EXCEPTION 'Select between 1 and 20 subjects.';
  END IF;
  IF (
    SELECT count(DISTINCT entry.value ->> 'subject_id')
    FROM jsonb_array_elements(p_expertise) AS entry(value)
  ) <> jsonb_array_length(p_expertise) THEN
    RAISE EXCEPTION 'A subject cannot be selected more than once.';
  END IF;

  SELECT mp.verification_status
    INTO v_status
    FROM public.mentor_profiles AS mp
   WHERE mp.user_id = v_user_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'A mentor application was not found for this account.';
  END IF;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'This action is only for an already approved mentor profile.';
  END IF;

  -- Every resubmission is forced into pending and inactive. The owner cannot choose status.
  UPDATE public.mentor_profiles
     SET teaching_bio = btrim(p_teaching_bio),
         teaching_experience = nullif(btrim(coalesce(p_teaching_experience, '')), ''),
         availability_notes = nullif(btrim(coalesce(p_availability_notes, '')), ''),
         online_available = p_online_available,
         offline_available = p_offline_available,
         verification_status = 'pending',
         is_active = false,
         updated_at = now()
   WHERE user_id = v_user_id;

  DELETE FROM public.mentor_expertise AS me
   WHERE me.mentor_id = v_user_id;

  FOR v_item IN
    SELECT entry.value FROM jsonb_array_elements(p_expertise) AS entry(value)
  LOOP
    IF coalesce(v_item ->> 'subject_id', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RAISE EXCEPTION 'A selected subject has an invalid identifier.';
    END IF;
    v_subject_id := (v_item ->> 'subject_id')::uuid;

    IF NOT EXISTS (SELECT 1 FROM public.subjects AS s WHERE s.id = v_subject_id) THEN
      RAISE EXCEPTION 'A selected subject was not found.';
    END IF;
    IF jsonb_typeof(v_item -> 'topics') IS DISTINCT FROM 'array' THEN
      RAISE EXCEPTION 'Each subject must include a list of topics.';
    END IF;

    SELECT coalesce(array_agg(btrim(topic.value)), ARRAY[]::text[])
      INTO v_topics
      FROM jsonb_array_elements_text(v_item -> 'topics') AS topic(value)
     WHERE btrim(topic.value) <> '';

    IF coalesce(array_length(v_topics, 1), 0) = 0 THEN
      RAISE EXCEPTION 'Each selected subject must include at least one topic.';
    END IF;
    IF EXISTS (SELECT 1 FROM unnest(v_topics) AS t(value) WHERE char_length(t.value) > 100) THEN
      RAISE EXCEPTION 'Each topic must be 100 characters or fewer.';
    END IF;

    INSERT INTO public.mentor_expertise (mentor_id, subject_id, topics)
    VALUES (v_user_id, v_subject_id, v_topics);
  END LOOP;
END;
$function$;

-- Only signed-in users can call this function. The function itself verifies auth.uid()
-- and only resubmits the caller's own currently-approved profile. It never approves a profile.
REVOKE ALL ON FUNCTION public.linked_resubmit_approved_mentor_profile(text, text, text, boolean, boolean, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.linked_resubmit_approved_mentor_profile(text, text, text, boolean, boolean, jsonb)
  TO authenticated;


-- ============================================================================
-- 13 — Account settings for basic profile fields
-- Source folded from: linked-account-settings-setup.sql
-- ============================================================================
-- LINKED: allow each signed-in user to update only their own basic profile fields.
-- This migration does not grant access to student_id or other sensitive fields.
DO $$
BEGIN
  IF to_regclass('public.profiles') IS NULL THEN
    RAISE EXCEPTION 'Required table public.profiles is missing. Confirm the correct LINKED project.';
  END IF;
END;
$$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Recreate a narrow owner-only policy so a user cannot edit another user's profile.
DROP POLICY IF EXISTS profile_owner_update ON public.profiles;
CREATE POLICY profile_owner_update
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Remove table-wide UPDATE if present; permit only basic, non-sensitive profile fields.
REVOKE UPDATE ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
GRANT UPDATE (full_name, study_program, cohort_year, updated_at)
  ON TABLE public.profiles TO authenticated;

-- The settings page reads only these non-sensitive fields.
GRANT SELECT (id, full_name, study_program, cohort_year, created_at, updated_at)
  ON TABLE public.profiles TO authenticated;


-- ============================================================================
-- FINAL READ-ONLY VERIFICATION QUERIES (run separately if desired)
-- ============================================================================
-- 1) Verify the expected application tables exist:
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND table_name IN (
--     'profiles','mentor_profiles','subjects','mentor_expertise','learning_requests',
--     'courses','course_modules','module_progress','sessions','reviews','opportunities',
--     'linked_admin_users','linked_notifications','support_tickets'
--   )
-- ORDER BY table_name;
--
-- 2) Verify RLS is enabled:
-- SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
-- FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public' AND c.relkind = 'r'
--   AND c.relname IN (
--     'profiles','mentor_profiles','subjects','mentor_expertise','learning_requests',
--     'courses','course_modules','module_progress','sessions','reviews','opportunities',
--     'linked_admin_users','linked_notifications','support_tickets'
--   )
-- ORDER BY c.relname;

COMMIT;
