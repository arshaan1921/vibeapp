-- Migration to add Social Links and Contact Info support to profiles table
-- Run this in your Supabase SQL Editor

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS instagram_handle TEXT,
ADD COLUMN IF NOT EXISTS twitter_handle TEXT,
ADD COLUMN IF NOT EXISTS facebook_handle TEXT,
ADD COLUMN IF NOT EXISTS linkedin_handle TEXT,
ADD COLUMN IF NOT EXISTS youtube_handle TEXT,
ADD COLUMN IF NOT EXISTS tiktok_handle TEXT,
ADD COLUMN IF NOT EXISTS snapchat_handle TEXT,
ADD COLUMN IF NOT EXISTS show_social_links BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS gmail_address TEXT,
ADD COLUMN IF NOT EXISTS show_gmail BOOLEAN DEFAULT FALSE;
