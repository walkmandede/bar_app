-- sql/002_functions.sql
-- Login, user creation (dev only), and the one function that changes stock.

-- Login: returns the user row if username and password match, otherwise no rows.
create or replace function app_login(p_username text, p_password text)
returns table (id uuid, username text, display_name text)
language sql
security definer
set search_path = public, extensions
as $$
  select u.id, u.username, u.display_name
  from app_users u
  where u.username = lower(trim(p_username))
    and u.password_hash = crypt(p_password, u.password_hash);
$$;

grant execute on function app_login(text, text) to anon, authenticated;

-- Create user: DEV ONLY. Run from the SQL Editor. The app cannot call it.
create or replace function create_app_user(p_username text, p_display_name text, p_password text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id uuid;
begin
  if p_password is null or length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters.';
  end if;

  insert into app_users (username, display_name, password_hash)
  values (lower(trim(p_username)), trim(p_display_name), crypt(p_password, gen_salt('bf')))
  returning id into v_id;

  return v_id;
end $$;

revoke execute on function create_app_user(text, text, text) from public, anon, authenticated;

-- Create a supply, sale, or manual entry and update stock in one transaction.
-- p_lines example: [{"item_id": "<uuid>", "quantity": 3}]
--   supply: quantity must be > 0 (adds stock)
--   sale:   quantity must be > 0 (removes stock)
--   manual: quantity is signed, not 0 (+ adds, - removes)
-- Any error rolls back everything.
create or replace function create_inventory_entry(
  p_user_id uuid,
  p_entry_type inventory_entry_type,
  p_reference_no text,
  p_entry_date date,
  p_note text,
  p_lines jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry_id uuid;
  v_line jsonb;
  v_item_id uuid;
  v_qty int;
  v_change int;
  v_current int;
  v_name text;
  v_ref text := nullif(trim(coalesce(p_reference_no, '')), '');
begin
  if not exists (select 1 from app_users where id = p_user_id) then
    raise exception 'Unknown user. Please log in again.';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'Add at least one item.';
  end if;

  if p_entry_type = 'sale' then
    if v_ref is null then
      raise exception 'Voucher number is required for sale orders.';
    end if;
    if exists (
      select 1 from inventory_entries
      where entry_type = 'sale' and lower(trim(reference_no)) = lower(v_ref)
    ) then
      raise exception 'Voucher number % is already used.', v_ref;
    end if;
  end if;

  insert into inventory_entries (entry_type, reference_no, note, entry_date, created_by)
  values (
    p_entry_type,
    v_ref,
    nullif(trim(coalesce(p_note, '')), ''),
    coalesce(p_entry_date, current_date),
    p_user_id
  )
  returning id into v_entry_id;

  -- Sorted by item id so two people saving at once cannot block each other
  for v_line in
    select value from jsonb_array_elements(p_lines) order by value->>'item_id'
  loop
    v_item_id := (v_line->>'item_id')::uuid;
    v_qty := (v_line->>'quantity')::int;

    if v_qty is null or v_qty = 0 then
      raise exception 'Quantity cannot be 0.';
    end if;

    if p_entry_type = 'supply' then
      if v_qty < 0 then raise exception 'Supply quantity must be more than 0.'; end if;
      v_change := v_qty;
    elsif p_entry_type = 'sale' then
      if v_qty < 0 then raise exception 'Sale quantity must be more than 0.'; end if;
      v_change := -v_qty;
    else
      v_change := v_qty;
    end if;

    select i.name into v_name from items i where i.id = v_item_id and i.is_active;
    if not found then
      raise exception 'An item in this order was not found or is archived.';
    end if;

    select s.quantity into v_current from item_stock s where s.item_id = v_item_id for update;

    if v_current + v_change < 0 then
      raise exception 'Not enough stock for %. Current stock: %, change: %.', v_name, v_current, v_change;
    end if;

    update item_stock
      set quantity = quantity + v_change, updated_at = now()
      where item_id = v_item_id;

    insert into inventory_entry_lines (entry_id, item_id, quantity_change)
    values (v_entry_id, v_item_id, v_change);
  end loop;

  return v_entry_id;
end $$;

grant execute on function create_inventory_entry(uuid, inventory_entry_type, text, date, text, jsonb)
  to anon, authenticated;