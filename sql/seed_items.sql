-- supabase/seed_items.sql
-- Run in Supabase SQL editor. Safe to run twice (skips existing serials / categories).
-- 66 items. Stock starts at 0 (nothing is written to inventory entries).

-- 1) Categories
insert into categories (name)
select v.name
from (values ('Bottles'),('Premium Alcohol'),('Sake'),('Soft Drinks'),('Beer'),('Champagne/Sparkling Wine')) as v(name)
where not exists (select 1 from categories c where lower(c.name) = lower(v.name));

-- 2) Items (item_serial = the SKU code from the sheet)
with u as (select id from app_users limit 1)
insert into items (item_serial, name, category_id, short_desc, size, variation, is_active, created_by, updated_by)
select v.serial, v.name,
       (select c.id from categories c where lower(c.name) = lower(v.cat) limit 1),
       '', '', '', true, u.id, u.id
from (values
    ('SKU-1001', 'Dewar''s 12 Years', 'Bottles'),
    ('SKU-1002', 'Suntory Whisky', 'Bottles'),
    ('SKU-1003', 'Hibiki Harmony', 'Bottles'),
    ('SKU-1004', 'Yamazaki 12 Years', 'Bottles'),
    ('SKU-1005', 'Regency Band', 'Bottles'),
    ('SKU-1006', 'Regency', 'Bottles'),
    ('SKU-1007', 'Hennessy VSOP 200ml', 'Bottles'),
    ('SKU-1008', 'Hennessy VSOP 70cl', 'Bottles'),
    ('SKU-1009', 'Hennessy X.O.', 'Bottles'),
    ('SKU-1010', 'Bombay Gin 200ml', 'Bottles'),
    ('SKU-1011', 'Hendrick''s Gin', 'Premium Alcohol'),
    ('SKU-1012', 'Grey Goose 200ml', 'Bottles'),
    ('SKU-1013', 'Grey Goose 70cl', 'Bottles'),
    ('SKU-1014', 'Clase Azul Tequila Reposado', 'Premium Alcohol'),
    ('SKU-1015', 'Don Julio Reposado', 'Bottles'),
    ('SKU-1016', 'Mini Azul 200ml', 'Bottles'),
    ('SKU-1017', 'Veuve Clicquot', 'Premium Alcohol'),
    ('SKU-1019', 'Gozenshu No.9', 'Sake'),
    ('SKU-1020', 'Gozenshu Yuzu', 'Sake'),
    ('SKU-1021', 'Gozenshu Yuzu 1.8L', 'Sake'),
    ('SKU-1024', 'Dassai 23 1.8L', 'Sake'),
    ('SKU-1025', 'Mio Sparkling Sake', 'Sake'),
    ('SKU-1026', 'Mio Sparkling Sake', 'Sake'),
    ('SKU-1027', 'HeavenSake Junmai Daiginjo', 'Sake'),
    ('SKU-1028', 'HeavenSake Junmai Ginjo', 'Sake'),
    ('SKU-1033', 'Coke', 'Soft Drinks'),
    ('SKU-1034', 'Coke Zero', 'Soft Drinks'),
    ('SKU-1035', 'S. Pellegrino Aranciata', 'Soft Drinks'),
    ('SKU-1038', 'Water', 'Soft Drinks'),
    ('SKU-1039', 'Soda Water', 'Soft Drinks'),
    ('SKU-1040', 'Acqua Panna Mineral Water', 'Soft Drinks'),
    ('SKU-1041', 'Sprite', 'Soft Drinks'),
    ('SKU-1042', 'Calpico', 'Soft Drinks'),
    ('SKU-1045', 'S. Pellegrino Tonic', 'Soft Drinks'),
    ('SKU-1046', 'Aqua Panna', 'Soft Drinks'),
    ('SKU-1047', 'S. Pellegrino Sparkling', 'Soft Drinks'),
    ('SKU-1049', 'Kirin Small', 'Beer'),
    ('SKU-1050', 'Kirin Big', 'Beer'),
    ('SKU-1053', 'Gozenshu', 'Sake'),
    ('SKU-1054', 'Dom Perignon', 'Champagne/Sparkling Wine'),
    ('SKU-1055', 'Bottega Gold', 'Champagne/Sparkling Wine'),
    ('SKU-1056', 'Mio Sparkling Sake 300ml', 'Sake'),
    ('SKU-1057', 'Hendrick''s Gin', 'Bottles'),
    ('SKU-1058', 'Dassai 23 300ml', 'Sake'),
    ('SKU-1059', 'Dassai 23 700ml', 'Sake'),
    ('SKU-1060', 'Calpis Soda', 'Soft Drinks'),
    ('SKU-1061', 'Red Bull', 'Soft Drinks'),
    ('SKU-1062', 'Tonic Water', 'Soft Drinks'),
    ('SKU-1063', 'Hennessy VSOP Japan Exclusive', 'Bottles'),
    ('SKU-1066', 'Tsushimaya Another Sake', 'Sake'),
    ('SKU-1067', 'Tsushimaya Green Day''s', 'Sake'),
    ('SKU-1068', 'Heaven Sake Junmai12', 'Sake'),
    ('SKU-1069', 'Mio Sparkling Sake 750ml', 'Sake'),
    ('SKU-1070', 'Veuve Clicquot', 'Champagne/Sparkling Wine'),
    ('SKU-1071', 'Gozenshu Bodimoto Nigori', 'Sake'),
    ('SKU-1072', 'Shichihonyari Junmai Watari Bune', 'Sake'),
    ('SKU-1073', 'Shichihonyari Junmai Genshu 14', 'Sake'),
    ('SKU-1074', 'Shichihonyari Junmai Big Blt', 'Sake'),
    ('SKU-1075', 'Niida Honke Odayaka', 'Sake'),
    ('SKU-1076', 'Sparkling Seafood', 'Sake'),
    ('SKU-1077', 'Kagatobi Junmai Dry Big', 'Sake'),
    ('SKU-1078', 'Kagatobi Junmai Dry Small', 'Sake'),
    ('SKU-1079', 'Kagatobi Junmai Ginjo Big', 'Sake'),
    ('SKU-1080', 'Kagatobi Junmai Ginjo Small', 'Sake'),
    ('SKU-1081', 'Emishiki Sensation White', 'Sake'),
    ('SKU-1082', 'Kagatobi Small', 'Sake')
) as v(serial, name, cat), u
where not exists (select 1 from items i where i.item_serial = v.serial);

-- 3) Check: should return 66 and all stock 0
select count(*) as items, coalesce(sum(s.quantity), 0) as total_stock
from items i left join item_stock s on s.item_id = i.id
where i.item_serial like 'SKU-%';

-- 4) Images later (one line per item):
-- update items set image_url = 'https://...' where item_serial = 'SKU-1001';