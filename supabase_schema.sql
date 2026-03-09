-- 0. Security & RBAC Infrastructure
CREATE TYPE public.user_role AS ENUM ('user', 'moderator', 'admin', 'owner');

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role public.user_role NOT NULL DEFAULT 'user',
    username TEXT UNIQUE,
    avatar_url TEXT,
    is_verified BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    display_name TEXT DEFAULT '',
    bio TEXT DEFAULT '',
    banner_url TEXT DEFAULT '',
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    chapters_read INTEGER DEFAULT 0,
    completed INTEGER DEFAULT 0,
    reading INTEGER DEFAULT 0,
    dropped INTEGER DEFAULT 0,
    on_hold INTEGER DEFAULT 0,
    planned INTEGER DEFAULT 0,
    top_genres JSONB DEFAULT '[]'::jsonb,
    top_picks JSONB DEFAULT '[]'::jsonb
);

-- User Follows Table
CREATE TABLE IF NOT EXISTS public.user_follows (
    follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (follower_id, following_id)
);

-- ----------------------------------------------------
-- CORE TABLES (Dependencies for Discussions & Stats)
-- ----------------------------------------------------

-- Mangas Table
CREATE TABLE IF NOT EXISTS public.mangas (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    cover_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- User Manga List (Library)
CREATE TABLE IF NOT EXISTS public.user_manga_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    manga_id INTEGER NOT NULL REFERENCES public.mangas(id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('Completed', 'Reading', 'Dropped', 'On Hold', 'Plan to Read')),
    rating FLOAT DEFAULT 0,
    is_favorite BOOLEAN DEFAULT false,
    last_read_id TEXT,
    last_read_page INTEGER DEFAULT 0,
    last_chapter_num TEXT DEFAULT '0',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, manga_id)
);

-- User Manga Notes
CREATE TABLE IF NOT EXISTS public.user_manga_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    manga_id INTEGER NOT NULL REFERENCES public.mangas(id) ON DELETE CASCADE,
    notes TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, manga_id)
);

-- Audit Logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    target_table TEXT,
    target_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ----------------------------------------------------
-- SOCIAL & NOTIFICATIONS
-- ----------------------------------------------------

-- Discussions (Manga Comments)
CREATE TABLE IF NOT EXISTS public.discussions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    manga_id INTEGER NOT NULL REFERENCES public.mangas(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    text_content TEXT NOT NULL,
    reply_to_id UUID REFERENCES public.discussions(id) ON DELETE SET NULL,
    metadata JSONB, -- For snips/replies info
    chapter_id TEXT, -- For chapter-specific discussions
    chapter_number TEXT, -- PRETTY chapter name/number (e.g. "5" or "Oneshot")
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Discussion Reactions
CREATE TABLE IF NOT EXISTS public.discussion_reactions (
    discussion_id UUID NOT NULL REFERENCES public.discussions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (discussion_id, user_id)
);

-- Content Reporting Table
CREATE TABLE public.content_reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id uuid REFERENCES auth.users(id) NOT NULL,
    content_type text NOT NULL, -- 'discussion'
    content_id uuid NOT NULL,
    reason text NOT NULL,
    details text,
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
    created_at timestamptz DEFAULT now()
);

-- Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('reply', 'new_chapter', 'follow', 'reaction', 'mention')),
    manga_id INTEGER REFERENCES public.mangas(id) ON DELETE CASCADE,
    chapter_id TEXT,
    chapter_number TEXT,
    discussion_id UUID REFERENCES public.discussions(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ----------------------------------------------------
-- RLS (ROW LEVEL SECURITY)
-- ----------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mangas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_manga_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_manga_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discussions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discussion_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

-- Alter user_manga_list to track chapters
ALTER TABLE public.user_manga_list ADD COLUMN IF NOT EXISTS latest_chapter_notified TEXT;

-- ----------------------------------------------------
-- HELPER FUNCTIONS
-- ----------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_mod() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role IN ('moderator', 'admin', 'owner')
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin' OR role = 'owner'
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_owner() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'owner'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ----------------------------------------------------
-- POLICIES
-- ----------------------------------------------------

-- Profiles: Users can view all, but only edit own (minimal). Admins can edit all.
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can edit own profiles" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can manage all profiles" ON public.profiles FOR ALL USING (public.is_admin());

-- Follows: Anyone can view, users manage their own outbound follows
CREATE POLICY "Anyone can view follows" ON public.user_follows FOR SELECT USING (true);
CREATE POLICY "Users can manage their follows" ON public.user_follows FOR ALL USING (auth.uid() = follower_id);

-- Audit Logs: Admin/Mod only
CREATE POLICY "Mods and Admins can view audit logs" ON public.audit_logs FOR SELECT USING (public.is_mod());

-- Mangas: Public Read, Mods can manage
CREATE POLICY "Anyone can view manga metadata" ON public.mangas FOR SELECT USING (true);
CREATE POLICY "Moderators can manage manga entries" ON public.mangas FOR ALL USING (public.is_mod());

-- Library & Notes: Public Read, User can manage own, Mods can DELETE for moderation
CREATE POLICY "Anyone can view library lists" ON public.user_manga_list FOR SELECT USING (true);
CREATE POLICY "Users can manage their own list" ON public.user_manga_list FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Moderators can delete inappropriate entries" ON public.user_manga_list FOR DELETE USING (public.is_mod());

CREATE POLICY "Anyone can view manga notes" ON public.user_manga_notes FOR SELECT USING (true);
CREATE POLICY "Users can manage their own notes" ON public.user_manga_notes FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Moderators can delete inappropriate notes" ON public.user_manga_notes FOR DELETE USING (public.is_mod());

-- RLS for content_reports
CREATE POLICY "Allow authenticated users to create reports"
ON public.content_reports FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Allow mods/admins to manage reports"
ON public.content_reports FOR ALL
TO authenticated
USING (public.is_mod() OR public.is_admin());

-- Discussions: Public Read, Auth Insert, Owner/Mod Delete
CREATE POLICY "Anyone can view discussions" ON public.discussions FOR SELECT USING (true);
CREATE POLICY "Authenticated users can post discussions" ON public.discussions FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Owners can edit/delete own discussions" ON public.discussions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Moderators can delete inappropriate discussions" ON public.discussions FOR DELETE USING (public.is_mod());

-- Reactions: Public Read, Auth manage own
CREATE POLICY "Anyone can view reactions" ON public.discussion_reactions FOR SELECT USING (true);
CREATE POLICY "Authenticated users can manage own reactions" ON public.discussion_reactions FOR ALL USING (auth.uid() = user_id);

-- Notifications: Auth manage own
CREATE POLICY "Users can manage their own notifications" ON public.notifications FOR ALL USING (auth.uid() = user_id);

-- ----------------------------------------------------
-- TRIGGERS
-- ----------------------------------------------------

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, role, username, display_name)
  VALUES (
    new.id, 
    'user', 
    COALESCE(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)), 
    COALESCE(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'username', 'User')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-create notification on reply
CREATE OR REPLACE FUNCTION public.handle_new_reply() RETURNS TRIGGER AS $$
BEGIN
  IF new.reply_to_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, manga_id, chapter_id, chapter_number, discussion_id, actor_id)
    SELECT
      parent.user_id,
      'reply',
      new.manga_id,
      new.chapter_id,
      new.chapter_number,
      new.id,
      new.user_id
    FROM public.discussions parent
    WHERE parent.id = new.reply_to_id AND parent.user_id != new.user_id;
  END IF;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_discussion_reply
  AFTER INSERT ON public.discussions
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_reply();

-- Auto-create notification on reaction
CREATE OR REPLACE FUNCTION public.handle_new_reaction() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, manga_id, chapter_id, chapter_number, discussion_id, reaction_emoji, actor_id)
  SELECT
    d.user_id,
    'reaction',
    d.manga_id,
    d.chapter_id,
    d.chapter_number,
    d.id,
    new.emoji,
    new.user_id
  FROM public.discussions d
  WHERE d.id = new.discussion_id AND d.user_id != new.user_id;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_discussion_reaction
  AFTER INSERT ON public.discussion_reactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_reaction();

-- Maintain Follower Counts
CREATE OR REPLACE FUNCTION public.handle_follow_stats() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET follower_count = follower_count + 1 WHERE id = NEW.following_id;
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    
    -- Auto-create notification on follow
    INSERT INTO public.notifications (user_id, type, actor_id)
    VALUES (NEW.following_id, 'follow', NEW.follower_id);
    
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET follower_count = GREATEST(follower_count - 1, 0) WHERE id = OLD.following_id;
    UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0) WHERE id = OLD.follower_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_user_follow
  AFTER INSERT OR DELETE ON public.user_follows
  FOR EACH ROW EXECUTE FUNCTION public.handle_follow_stats();

-- ----------------------------------------------------
-- INDEXES
-- ----------------------------------------------------

CREATE INDEX idx_user_manga_user_id ON public.user_manga_list(user_id);
CREATE INDEX idx_audit_logs_actor ON public.audit_logs(actor_id);
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_discussions_manga_id ON public.discussions(manga_id);
CREATE INDEX idx_discussions_reply_id ON public.discussions(reply_to_id);
CREATE INDEX idx_discussions_chapter_id ON public.discussions(chapter_id);
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX idx_user_follows_follower ON public.user_follows(follower_id);
CREATE INDEX idx_user_follows_following ON public.user_follows(following_id);

-- ----------------------------------------------------
-- CHAT EXTENSION SCHEMA
-- ----------------------------------------------------

-- Chat Rooms List
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    is_group BOOLEAN NOT NULL DEFAULT false,
    group_name TEXT,
    group_icon_url TEXT,
    admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    last_message_text TEXT,
    last_message_sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    last_message_timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Chat Participants
CREATE TABLE IF NOT EXISTS public.chat_room_participants (
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    unread_count INTEGER DEFAULT 0,
    currently_viewing BOOLEAN DEFAULT false,
    joined_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (room_id, user_id)
);

-- Chat Messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    reply_to_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
    is_edited BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

-- Chat Message Reactions
CREATE TABLE IF NOT EXISTS public.chat_message_reactions (
    message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (message_id, user_id)
);

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_message_reactions ENABLE ROW LEVEL SECURITY;

-- Helper to check if user is a participant of a room
CREATE OR REPLACE FUNCTION public.is_room_participant(check_room_id UUID) RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_room_participants 
    WHERE room_id = check_room_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Chat Room Policies
CREATE POLICY "Users can view their chat rooms" ON public.chat_rooms 
FOR SELECT USING (
  public.is_room_participant(id) 
  OR auth.uid() = admin_id 
  OR auth.uid() = last_message_sender_id
);

CREATE POLICY "Authenticated users can create chat rooms" ON public.chat_rooms 
FOR INSERT TO authenticated WITH CHECK (auth.uid() = admin_id OR auth.uid() = last_message_sender_id);

CREATE POLICY "Participants can update chat rooms (e.g., last message)" ON public.chat_rooms 
FOR UPDATE USING (public.is_room_participant(id));

-- Chat Participants Policies 
CREATE POLICY "Participants can see others in the room" ON public.chat_room_participants 
FOR SELECT USING (public.is_room_participant(room_id));

CREATE POLICY "Users can add participants" ON public.chat_room_participants 
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update their own participation status" ON public.chat_room_participants 
FOR UPDATE USING (auth.uid() = user_id);

-- Chat Messages Policies
CREATE POLICY "Participants can view room messages" ON public.chat_messages 
FOR SELECT USING (public.is_room_participant(room_id));

CREATE POLICY "Participants can send messages" ON public.chat_messages 
FOR INSERT WITH CHECK (public.is_room_participant(room_id) AND auth.uid() = sender_id);

CREATE POLICY "Senders can edit their own messages" ON public.chat_messages 
FOR UPDATE USING (auth.uid() = sender_id);

CREATE POLICY "Senders can delete their own messages" ON public.chat_messages 
FOR DELETE USING (auth.uid() = sender_id);

-- Chat Message Reactions Policies
CREATE POLICY "Participants can view message reactions" ON public.chat_message_reactions 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.chat_messages cm 
    WHERE cm.id = message_id AND public.is_room_participant(cm.room_id)
  )
);

CREATE POLICY "Users can add/manage their own reactions" ON public.chat_message_reactions 
FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_chat_participants_user ON public.chat_room_participants(user_id);
CREATE INDEX idx_chat_messages_room ON public.chat_messages(room_id);
CREATE INDEX idx_chat_messages_created ON public.chat_messages(created_at DESC);

-- ----------------------------------------------------
-- CHAT RPC FUNCTIONS
-- ----------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_direct_chat_room(p1 UUID, p2 UUID) 
RETURNS UUID AS $$
DECLARE
  found_room_id UUID;
BEGIN
  SELECT r.id INTO found_room_id
  FROM public.chat_rooms r
  WHERE r.is_group = false 
    AND (
      SELECT COUNT(*) 
      FROM public.chat_room_participants p 
      WHERE p.room_id = r.id AND p.user_id IN (p1, p2)
    ) = 2
    AND (
      SELECT COUNT(*) 
      FROM public.chat_room_participants p 
      WHERE p.room_id = r.id
    ) = 2
  LIMIT 1;
  
  RETURN found_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.increment_unread_counts(c_room_id UUID, c_sender_id UUID) 
RETURNS VOID AS $$
BEGIN
  UPDATE public.chat_room_participants
  SET unread_count = unread_count + 1
  WHERE room_id = c_room_id 
    AND user_id != c_sender_id 
    AND currently_viewing = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------
-- AUTHENTICATION RPC FUNCTIONS
-- ----------------------------------------------------

CREATE OR REPLACE FUNCTION public.check_username_available(requested_username TEXT)
RETURNS BOOLEAN AS $$
  SELECT NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = requested_username);
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.login_with_username(login_identifier TEXT, login_password TEXT)
RETURNS JSONB AS $$
DECLARE
  res_email TEXT;
BEGIN
  IF login_identifier ~* '^[A-Za-z0-9._%+-]+@' THEN
    res_email := login_identifier;
  ELSE
    SELECT u.email INTO res_email
    FROM auth.users u JOIN public.profiles p ON u.id = p.id
    WHERE p.username = login_identifier;
  END IF;
  RETURN jsonb_build_object('email', res_email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------
-- MANGA METADATA SYNC RPC
-- ----------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_manga_metadata(
    p_id INTEGER, 
    p_title TEXT, 
    p_cover_url TEXT, 
    p_description TEXT
) RETURNS VOID AS $$
BEGIN
  -- We use SECURITY DEFINER to allow regular users to "seed" the mangas table
  -- but we use ON CONFLICT DO NOTHING to prevent them from modifying existing entries
  -- which is reserved for moderators/admins.
  INSERT INTO public.mangas (id, title, cover_url, description, updated_at)
  VALUES (p_id, p_title, p_cover_url, p_description, now())
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------
-- MANGA STATS EXTENSION SCHEMA
-- ----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.manga_stats (
    manga_id INTEGER PRIMARY KEY REFERENCES public.mangas(id) ON DELETE CASCADE,
    bookmark_count INTEGER DEFAULT 0,
    rating_sum FLOAT DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    average_rating FLOAT DEFAULT 0.0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.manga_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view manga stats" ON public.manga_stats FOR SELECT USING (true);

CREATE OR REPLACE FUNCTION public.handle_manga_stats_change() RETURNS TRIGGER AS $$
DECLARE
  old_rating FLOAT := 0;
  new_rating FLOAT := 0;
  old_is_bookmarked BOOLEAN := false;
  new_is_bookmarked BOOLEAN := false;
  
  delta_bookmark INTEGER := 0;
  delta_rating_sum FLOAT := 0;
  delta_rating_count INTEGER := 0;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    old_rating := COALESCE(OLD.rating, 0);
    old_is_bookmarked := OLD.status IS NOT NULL;
  END IF;
  
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    new_rating := COALESCE(NEW.rating, 0);
    new_is_bookmarked := NEW.status IS NOT NULL;
  END IF;
  
  IF new_is_bookmarked AND NOT old_is_bookmarked THEN
    delta_bookmark := 1;
  ELSIF old_is_bookmarked AND NOT new_is_bookmarked THEN
    delta_bookmark := -1;
  END IF;
  
  IF new_rating > 0 AND old_rating = 0 THEN
    delta_rating_count := 1;
    delta_rating_sum := new_rating;
  ELSIF old_rating > 0 AND new_rating = 0 THEN
    delta_rating_count := -1;
    delta_rating_sum := -old_rating;
  ELSIF old_rating > 0 AND new_rating > 0 AND old_rating != new_rating THEN
    delta_rating_sum := new_rating - old_rating;
  END IF;
  
  IF delta_bookmark = 0 AND delta_rating_count = 0 AND delta_rating_sum = 0 THEN
    RETURN NULL;
  END IF;
  
  INSERT INTO public.manga_stats (manga_id, bookmark_count, rating_sum, rating_count, average_rating)
  VALUES (
    COALESCE(NEW.manga_id, OLD.manga_id), 
    GREATEST(delta_bookmark, 0), 
    GREATEST(delta_rating_sum, 0::FLOAT), 
    GREATEST(delta_rating_count, 0), 
    CASE WHEN GREATEST(delta_rating_count, 0) > 0 THEN GREATEST(delta_rating_sum, 0::FLOAT) / GREATEST(delta_rating_count, 0) ELSE 0 END
  )
  ON CONFLICT (manga_id)
  DO UPDATE SET 
    bookmark_count = GREATEST(public.manga_stats.bookmark_count + delta_bookmark, 0),
    rating_sum = GREATEST(public.manga_stats.rating_sum + delta_rating_sum, 0::FLOAT),
    rating_count = GREATEST(public.manga_stats.rating_count + delta_rating_count, 0),
    average_rating = CASE 
      WHEN (public.manga_stats.rating_count + delta_rating_count) > 0 
      THEN GREATEST(public.manga_stats.rating_sum + delta_rating_sum, 0::FLOAT) / (public.manga_stats.rating_count + delta_rating_count)
      ELSE 0
    END,
    updated_at = now();
    
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_user_manga_list_change
  AFTER INSERT OR UPDATE OR DELETE ON public.user_manga_list
  FOR EACH ROW EXECUTE FUNCTION public.handle_manga_stats_change();

-- ----------------------------------------------------
-- USER PROFILE MANGA STATS
-- ----------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_user_manga_counts() RETURNS TRIGGER AS $$
DECLARE
  old_status TEXT := NULL;
  new_status TEXT := NULL;
  
  c_read_delta INTEGER := 0;
  c_completed_delta INTEGER := 0;
  c_reading_delta INTEGER := 0;
  c_dropped_delta INTEGER := 0;
  c_on_hold_delta INTEGER := 0;
  c_planned_delta INTEGER := 0;
  
  user_uuid UUID;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    old_status := OLD.status;
  END IF;
  
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    new_status := NEW.status;
    user_uuid := NEW.user_id;
  ELSE
    user_uuid := OLD.user_id;
  END IF;
  
  IF old_status IS NOT DISTINCT FROM new_status AND TG_OP = 'UPDATE' THEN
    IF COALESCE(OLD.last_read_page, 0) != COALESCE(NEW.last_read_page, 0) 
       OR COALESCE(OLD.last_chapter_num, '0') != COALESCE(NEW.last_chapter_num, '0') THEN
      RETURN NULL;
    END IF;
  END IF;

  IF old_status IS NOT NULL THEN
    IF old_status = 'Completed' THEN c_completed_delta := -1;
    ELSIF old_status = 'Reading' THEN c_reading_delta := -1;
    ELSIF old_status = 'Dropped' THEN c_dropped_delta := -1;
    ELSIF old_status = 'On Hold' THEN c_on_hold_delta := -1;
    ELSIF old_status = 'Plan to Read' THEN c_planned_delta := -1;
    END IF;
  END IF;
  
  IF new_status IS NOT NULL AND (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    IF new_status = 'Completed' THEN c_completed_delta := 1;
    ELSIF new_status = 'Reading' THEN c_reading_delta := 1;
    ELSIF new_status = 'Dropped' THEN c_dropped_delta := 1;
    ELSIF new_status = 'On Hold' THEN c_on_hold_delta := 1;
    ELSIF new_status = 'Plan to Read' THEN c_planned_delta := 1;
    END IF;
  END IF;
  
  IF c_completed_delta != 0 OR c_reading_delta != 0 OR c_dropped_delta != 0 OR c_on_hold_delta != 0 OR c_planned_delta != 0 THEN
    UPDATE public.profiles SET
      completed = GREATEST(completed + c_completed_delta, 0),
      reading = GREATEST(reading + c_reading_delta, 0),
      dropped = GREATEST(dropped + c_dropped_delta, 0),
      on_hold = GREATEST(on_hold + c_on_hold_delta, 0),
      planned = GREATEST(planned + c_planned_delta, 0)
    WHERE id = user_uuid;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_user_manga_status_change
  AFTER INSERT OR UPDATE OR DELETE ON public.user_manga_list
  FOR EACH ROW EXECUTE FUNCTION public.handle_user_manga_counts();

-- ----------------------------------------------------
-- ENABLE REALTIME
-- ----------------------------------------------------

BEGIN;
  -- Remove existing if any to avoid duplicates
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime;
COMMIT;

ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_room_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_message_reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.discussions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.discussion_reactions;

-- Real-time Reaction Sync:
-- Function to update message timestamp on reaction change
-- This forces the chat_messages stream to re-emit when a reaction is added/deleted
CREATE OR REPLACE FUNCTION public.handle_message_reaction_change()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chat_messages
    SET updated_at = now()
    WHERE id = COALESCE(NEW.message_id, OLD.message_id);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for reactions
DROP TRIGGER IF EXISTS on_message_reaction_change ON public.chat_message_reactions;
CREATE TRIGGER on_message_reaction_change
AFTER INSERT OR DELETE ON public.chat_message_reactions
FOR EACH ROW EXECUTE FUNCTION public.handle_message_reaction_change();

-- Function to poke replying messages when a parent message is deleted
-- This ensures that replies to a deleted message show "Message deleted" instantly
CREATE OR REPLACE FUNCTION public.handle_message_delete_poke()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chat_messages
    SET updated_at = now()
    WHERE reply_to_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger for message deletion
DROP TRIGGER IF EXISTS on_message_delete_poke ON public.chat_messages;
CREATE TRIGGER on_message_delete_poke
BEFORE DELETE ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.handle_message_delete_poke();

-- Function to sync last message info to chat_rooms
-- Fires after insert, delete, or message edit to keep chat list accurate
CREATE OR REPLACE FUNCTION public.sync_room_last_message()
RETURNS TRIGGER AS $$
DECLARE
    latest_msg RECORD;
BEGIN
    SELECT message_text, sender_id, created_at
    INTO latest_msg
    FROM public.chat_messages
    WHERE room_id = COALESCE(NEW.room_id, OLD.room_id)
    ORDER BY created_at DESC
    LIMIT 1;

    UPDATE public.chat_rooms
    SET 
        last_message_text = latest_msg.message_text,
        last_message_sender_id = latest_msg.sender_id,
        last_message_timestamp = latest_msg.created_at,
        updated_at = now()
    WHERE id = COALESCE(NEW.room_id, OLD.room_id);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for sync
DROP TRIGGER IF EXISTS on_message_sync_last_message ON public.chat_messages;
CREATE TRIGGER on_message_sync_last_message
AFTER INSERT OR DELETE OR UPDATE OF message_text ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.sync_room_last_message();