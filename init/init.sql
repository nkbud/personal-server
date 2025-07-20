-- Enable necessary extensions
create extension if not exists "uuid-ossp" schema public version '1.1';
create extension if not exists "pgcrypto" schema public version '1.3';
create extension if not exists "pgjwt" schema public version '0.2.0';

-- Create auth schema
create schema if not exists auth;

-- Create user roles
create role anon nologin noinherit;
create role authenticated nologin noinherit;
create role service_role nologin noinherit bypassrls;
create role authenticator noinherit;

grant anon to authenticator;
grant authenticated to authenticator;
grant service_role to authenticator;

-- Create a user for auth service
create role supabase_auth_admin noinherit createrole createdb;

-- Grant necessary privileges
grant all privileges on database postgres to supabase_auth_admin;
grant all privileges on schema auth to supabase_auth_admin;
grant all privileges on all tables in schema auth to supabase_auth_admin;
grant all privileges on all sequences in schema auth to supabase_auth_admin;

-- Allow anon and authenticated to access public schema
grant usage on schema public to anon, authenticated, service_role;
grant all privileges on all tables in schema public to anon, authenticated, service_role;
grant all privileges on all functions in schema public to anon, authenticated, service_role;
grant all privileges on all sequences in schema public to anon, authenticated, service_role;

-- Default privileges for future objects
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- Create basic auth tables (simplified version)
create table if not exists auth.users (
    id uuid primary key default uuid_generate_v4(),
    email varchar(255) unique not null,
    encrypted_password varchar(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token varchar(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token varchar(255),
    recovery_sent_at timestamp with time zone,
    email_change_token varchar(255),
    email_change varchar(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now(),
    phone varchar(15),
    phone_confirmed_at timestamp with time zone,
    phone_change varchar(15),
    phone_change_token varchar(255),
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone generated always as (least(email_confirmed_at, phone_confirmed_at)) stored,
    email_change_confirm_status smallint default 0,
    banned_until timestamp with time zone,
    reauthentication_token varchar(255),
    reauthentication_sent_at timestamp with time zone
);

-- RLS policies for auth.users
alter table auth.users enable row level security;

-- Only service_role can view users
create policy "Allow service_role to read users" on auth.users
    for select using (auth.role() = 'service_role');

-- Only service_role can insert users
create policy "Allow service_role to insert users" on auth.users
    for insert with check (auth.role() = 'service_role');

-- Only service_role can update users
create policy "Allow service_role to update users" on auth.users
    for update using (auth.role() = 'service_role');

-- Users can view their own data
create policy "Users can view their own data" on auth.users
    for select using (auth.uid() = id);

-- Create auth helper functions
create or replace function auth.uid() returns uuid
language sql stable
as $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim.sub', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    )::uuid
$$;

create or replace function auth.role() returns text
language sql stable
as $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim.role', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
    )::text
$$;

-- Create example table to demonstrate functionality
create table if not exists public.profiles (
    id uuid references auth.users on delete cascade primary key,
    updated_at timestamp with time zone default now(),
    username text unique,
    full_name text,
    avatar_url text,
    website text,
    
    constraint username_length check (char_length(username) >= 3)
);

-- RLS policies for profiles
alter table public.profiles enable row level security;

-- Users can view all profiles
create policy "Public profiles are viewable by everyone" on public.profiles
    for select using (true);

-- Users can insert their own profile
create policy "Users can insert their own profile" on public.profiles
    for insert with check (auth.uid() = id);

-- Users can update their own profile
create policy "Users can update their own profile" on public.profiles
    for update using (auth.uid() = id);

-- Trigger to create profile on user signup
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Note: This trigger would need to be set up by the auth service
-- create trigger on_auth_user_created
--   after insert on auth.users
--   for each row execute procedure public.handle_new_user();