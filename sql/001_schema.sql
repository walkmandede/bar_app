-- sql/001_schema.sql
-- Tables, indexes, triggers, and access rules.

create extension if not exists pgcrypto with schema extensions;

create type inventory_entry_type as enum ('supply', 'sale', 'manual');

-- Users (simple custom auth for now; replaced by Supabase Auth later)
create table app_users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  display_name text not null,
  password_hash text not null,
  created_at timestamptz not null default now(),
  constraint app_users_username_format check (username ~ '^[a-z][a-z0-9]*$')
);

create table brands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);
create unique index brands_name_unique on brands (lower(name));

create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);
create unique index categories_name_unique on categories (lower(name));

create table items (
  id uuid primary key default gen_random_uuid(),
  item_serial text not null unique,
  brand_id uuid references brands(id) on delete set null,
  category_id uuid references categories(id) on delete set null,
  image_url text,
  name text not null,
  short_desc text not null default '',
  size text not null default '',
  variation text not null default '',
  is_active boolean not null default true,
  created_by uuid not null references app_users(id),
  updated_by uuid not null references app_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table item_stock (
  item_id uuid primary key references items(id) on delete cascade,
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now()
);

create table inventory_entries (
  id uuid primary key default gen_random_uuid(),
  entry_type inventory_entry_type not null,
  reference_no text,
  note text,
  entry_date date not null default current_date,
  created_by uuid not null references app_users(id),
  created_at timestamptz not null default now(),
  constraint sale_needs_reference check (
    entry_type <> 'sale' or (reference_no is not null and length(trim(reference_no)) > 0)
  )
);
-- Same voucher number cannot be used twice for sales
create unique index inventory_entries_sale_ref_unique
  on inventory_entries (lower(trim(reference_no))) where entry_type = 'sale';
create index inventory_entries_date_idx on inventory_entries (entry_date);

create table inventory_entry_lines (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references inventory_entries(id) on delete cascade,
  item_id uuid not null references items(id),
  quantity_change integer not null check (quantity_change <> 0)
);
create index inventory_entry_lines_entry_idx on inventory_entry_lines (entry_id);
create index inventory_entry_lines_item_idx on inventory_entry_lines (item_id);

-- Triggers
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger items_touch_updated_at before update on items
  for each row execute function touch_updated_at();

create or replace function create_item_stock() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into item_stock (item_id, quantity) values (new.id, 0);
  return new;
end $$;

create trigger items_create_stock after insert on items
  for each row execute function create_item_stock();

-- Access rules (TEMPORARY open rules for anon key until Supabase Auth is added)
alter table app_users enable row level security;
alter table brands enable row level security;
alter table categories enable row level security;
alter table items enable row level security;
alter table item_stock enable row level security;
alter table inventory_entries enable row level security;
alter table inventory_entry_lines enable row level security;

-- app_users: only id, username, display_name can be read. Hash is never readable.
revoke all on app_users from anon, authenticated;
grant select (id, username, display_name) on app_users to anon, authenticated;
create policy app_users_select on app_users for select to anon, authenticated using (true);

create policy brands_select on brands for select to anon, authenticated using (true);
create policy brands_insert on brands for insert to anon, authenticated with check (true);

create policy categories_select on categories for select to anon, authenticated using (true);
create policy categories_insert on categories for insert to anon, authenticated with check (true);

create policy items_select on items for select to anon, authenticated using (true);
create policy items_insert on items for insert to anon, authenticated with check (true);
create policy items_update on items for update to anon, authenticated using (true) with check (true);

-- Stock and history: read only. Writes happen only through create_inventory_entry().
create policy item_stock_select on item_stock for select to anon, authenticated using (true);
create policy entries_select on inventory_entries for select to anon, authenticated using (true);
create policy lines_select on inventory_entry_lines for select to anon, authenticated using (true);

revoke insert, update, delete on item_stock, inventory_entries, inventory_entry_lines
  from anon, authenticated;
revoke delete on items, brands, categories from anon, authenticated;