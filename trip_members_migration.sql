-- ============================================================
-- Trip Collaboration Migration
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. Create trip_members table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.trip_members (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id           UUID        NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id           UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
    invited_by        UUID        NOT NULL REFERENCES auth.users(id),
    invited_email     TEXT,
    role              TEXT        NOT NULL DEFAULT 'editor'
                                  CHECK (role IN ('editor', 'viewer')),
    status            TEXT        NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending', 'accepted', 'declined')),
    invite_token      TEXT        UNIQUE,
    invite_expires_at TIMESTAMPTZ,
    joined_at         TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS trip_members_trip_id_idx ON public.trip_members(trip_id);
CREATE INDEX IF NOT EXISTS trip_members_user_id_idx ON public.trip_members(user_id);
CREATE INDEX IF NOT EXISTS trip_members_token_idx   ON public.trip_members(invite_token);

-- 2. Enable Realtime on trips and trip_members
-- ============================================================
ALTER TABLE public.trips        REPLICA IDENTITY FULL;
ALTER TABLE public.trip_members REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_members;

-- 3. Enable RLS
-- ============================================================
ALTER TABLE public.trip_members ENABLE ROW LEVEL SECURITY;

-- 4. RLS policies on trip_members
-- ============================================================

-- Trip owner can see all members of their trips
CREATE POLICY "trip_members_owner_select"
ON public.trip_members FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.trips
        WHERE trips.id = trip_members.trip_id
          AND trips.user_id = auth.uid()
    )
);

-- Accepted members can see other members in the same trip
CREATE POLICY "trip_members_member_select"
ON public.trip_members FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.trip_members tm
        WHERE tm.trip_id = trip_members.trip_id
          AND tm.user_id = auth.uid()
          AND tm.status  = 'accepted'
    )
);

-- Anyone authenticated can read a row by a valid, unexpired invite token
CREATE POLICY "trip_members_token_lookup"
ON public.trip_members FOR SELECT
USING (
    invite_token IS NOT NULL
    AND invite_expires_at > now()
    AND auth.uid() IS NOT NULL
);

-- Trip owner can invite (insert) members
CREATE POLICY "trip_members_owner_insert"
ON public.trip_members FOR INSERT
WITH CHECK (
    invited_by = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.trips
        WHERE trips.id = trip_members.trip_id
          AND trips.user_id = auth.uid()
    )
);

-- Any authenticated user can accept their own invite
-- (update: set user_id = me, status = accepted)
CREATE POLICY "trip_members_accept_invite"
ON public.trip_members FOR UPDATE
USING (
    invite_token IS NOT NULL
    AND invite_expires_at > now()
    AND status = 'pending'
    AND auth.uid() IS NOT NULL
)
WITH CHECK (
    user_id = auth.uid()
    AND status = 'accepted'
);

-- Trip owner can change roles / revoke members
CREATE POLICY "trip_members_owner_update"
ON public.trip_members FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.trips
        WHERE trips.id = trip_members.trip_id
          AND trips.user_id = auth.uid()
    )
);

-- Trip owner or the member themselves can delete the row
CREATE POLICY "trip_members_delete"
ON public.trip_members FOR DELETE
USING (
    user_id = auth.uid()        -- member leaves voluntarily
    OR EXISTS (
        SELECT 1 FROM public.trips
        WHERE trips.id = trip_members.trip_id
          AND trips.user_id = auth.uid()
    )
);

-- 5. Extend trips RLS to allow members to read/edit
-- ============================================================
-- (These add to existing owner policies — do NOT drop owner policies)

CREATE POLICY "trips_member_select"
ON public.trips FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.trip_members tm
        WHERE tm.trip_id = trips.id
          AND tm.user_id = auth.uid()
          AND tm.status  = 'accepted'
    )
);

CREATE POLICY "trips_editor_update"
ON public.trips FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.trip_members tm
        WHERE tm.trip_id = trips.id
          AND tm.user_id = auth.uid()
          AND tm.status  = 'accepted'
          AND tm.role     = 'editor'
    )
);

-- 6. Extend expenses RLS so members can see all trip expenses
-- ============================================================
-- Members can read all expenses for their shared trips
CREATE POLICY "expenses_member_select"
ON public.expenses FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.trip_members tm
        WHERE tm.trip_id = expenses.trip_id
          AND tm.user_id = auth.uid()
          AND tm.status  = 'accepted'
    )
);

-- Members (editor role) can insert their own expenses
CREATE POLICY "expenses_member_insert"
ON public.expenses FOR INSERT
WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.trip_members tm
        WHERE tm.trip_id = expenses.trip_id
          AND tm.user_id = auth.uid()
          AND tm.status  = 'accepted'
    )
);

-- Users can only delete their own expenses
CREATE POLICY "expenses_owner_delete"
ON public.expenses FOR DELETE
USING ( user_id = auth.uid() );
