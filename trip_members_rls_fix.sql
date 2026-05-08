-- ============================================================
-- RLS Infinite Recursion Fix
-- Run this AFTER trip_members_migration.sql
--
-- Root cause: trips_member_select checks trip_members, and
-- trip_members_owner_select checks trips — circular dependency.
-- Fix: SECURITY DEFINER helper functions bypass RLS internally,
-- breaking the cycle.
-- ============================================================

-- 1. Helper functions (SECURITY DEFINER = no RLS when they run)
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_trip_owner(p_trip_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
    SELECT EXISTS (
        SELECT 1 FROM trips
        WHERE id = p_trip_id AND user_id = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION public.is_trip_member(p_trip_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
    SELECT EXISTS (
        SELECT 1 FROM trip_members
        WHERE trip_id = p_trip_id
          AND user_id = auth.uid()
          AND status  = 'accepted'
    );
$$;

CREATE OR REPLACE FUNCTION public.is_trip_editor(p_trip_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
    SELECT EXISTS (
        SELECT 1 FROM trip_members
        WHERE trip_id = p_trip_id
          AND user_id = auth.uid()
          AND status  = 'accepted'
          AND role    = 'editor'
    );
$$;

-- 2. Drop the circular policies
-- ============================================================

DROP POLICY IF EXISTS "trip_members_owner_select"  ON public.trip_members;
DROP POLICY IF EXISTS "trip_members_member_select"  ON public.trip_members;
DROP POLICY IF EXISTS "trip_members_owner_insert"   ON public.trip_members;
DROP POLICY IF EXISTS "trip_members_owner_update"   ON public.trip_members;
DROP POLICY IF EXISTS "trip_members_delete"         ON public.trip_members;
DROP POLICY IF EXISTS "trips_member_select"         ON public.trips;
DROP POLICY IF EXISTS "trips_editor_update"         ON public.trips;

-- 3. Recreate trip_members policies using helper functions
-- ============================================================

-- Trip owner can see all members of their trips
CREATE POLICY "trip_members_owner_select"
ON public.trip_members FOR SELECT
USING ( is_trip_owner(trip_id) );

-- Accepted members can see the other members
CREATE POLICY "trip_members_member_select"
ON public.trip_members FOR SELECT
USING ( is_trip_member(trip_id) );

-- Trip owner can invite (insert) new members
CREATE POLICY "trip_members_owner_insert"
ON public.trip_members FOR INSERT
WITH CHECK (
    invited_by = auth.uid()
    AND is_trip_owner(trip_id)
);

-- Trip owner can change roles
CREATE POLICY "trip_members_owner_update"
ON public.trip_members FOR UPDATE
USING ( is_trip_owner(trip_id) );

-- Owner can remove members; members can remove themselves
CREATE POLICY "trip_members_delete"
ON public.trip_members FOR DELETE
USING (
    user_id = auth.uid()
    OR is_trip_owner(trip_id)
);

-- 4. Recreate trips policies using helper functions
-- ============================================================

-- Accepted members can read trips they were invited to
CREATE POLICY "trips_member_select"
ON public.trips FOR SELECT
USING ( is_trip_member(id) );

-- Editors can update the trip (itinerary, etc.)
CREATE POLICY "trips_editor_update"
ON public.trips FOR UPDATE
USING ( is_trip_editor(id) );
