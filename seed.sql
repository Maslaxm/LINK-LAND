-- ============================================================================
-- LINK-LAND - seed data
-- Run AFTER schema.sql. Safe to re-run (uses deterministic ids + ON CONFLICT).
--
-- The first super admin is NOT seeded here. Create the account in Supabase
-- Authentication (email + password), then run:
--   select public.bootstrap_super_admin('ishanews7@gmail.com');
-- Passwords are handled only by Supabase Auth and never stored in SQL tables.
-- ============================================================================

begin;

select set_config('app.bypass_guards', 'on', false);

-- Settings -------------------------------------------------------------------
insert into public.settings (
  id, site_name, logo_url, tagline_so, tagline_en,
  default_whatsapp, phone, email, address,
  facebook, instagram, tiktok, twitter, youtube,
  footer_so, footer_en, about_so, about_en,
  default_currency, deposit_amount, listing_fee, featured_fee, featured_days
) values (
  1,
  'LINK-LAND',
  '/logo.svg',
  'Guri iyo Dhul iibka & kirada',
  'Houses & land for sale and rent',
  '+252617179076',
  '+252617179076',
  'linkland@gmail.com',
  'Mogadishu, Somalia',
  'https://facebook.com/linkland',
  'https://instagram.com/linkland',
  'https://tiktok.com/@linkland',
  'https://x.com/linkland',
  null,
  'LINK-LAND waxay isu keentaa iibiyeyaasha, kireystayaasha iyo macaamiisha Soomaaliyeed ee guryaha iyo dhulka.',
  'LINK-LAND connects Somali buyers, renters, agents and sellers of houses and land.',
  'LINK-LAND waa suuq casri ah oo lagu iibiyo laguna kireeyo guryaha iyo dhulka Soomaaliya. Waxaan u fududeynaynaa inaad hesho guri ama dhul la xaqiijiyay, oo leh sawirro cad, qiimo hufan iyo wakiillo la aamini karo.',
  'LINK-LAND is a modern marketplace for buying and renting houses and land in Somalia. We make it easy to find verified properties with clear photos, transparent pricing and trusted agents.',
  'USD', 100, 10, 25, 30
)
on conflict (id) do nothing;

-- Mobile money / payment settings --------------------------------------------
insert into public.payment_settings (method, merchant_number, account_name, instructions_so, instructions_en, enabled) values
  ('evc_plus', '+252 61 555 0000', 'LINK-LAND',
   'Dir lacagta adiga oo isticmaalaya EVC Plus. Geli lambarka ganacsiga, lacagta ballanta, kadibna koobi lambarka xawaaladda (transaction ID) oo halkan ku qor.',
   'Send the deposit using EVC Plus to the merchant number, then copy the transaction ID and enter it here.',
   true),
  ('edahab', '+252 65 555 0000', 'LINK-LAND',
   'Dir lacagta adiga oo isticmaalaya eDahab. Geli lambarka ganacsiga, lacagta ballanta, kadibna koobi lambarka xawaaladda oo halkan ku qor.',
   'Send the deposit using eDahab to the merchant number, then copy the transaction ID and enter it here.',
   true),
  ('zaad', '+252 63 555 0000', 'LINK-LAND',
   'Dir lacagta adiga oo isticmaalaya Zaad. Geli lambarka ganacsiga, lacagta ballanta, kadibna koobi lambarka xawaaladda oo halkan ku qor.',
   'Send the deposit using Zaad to the merchant number, then copy the transaction ID and enter it here.',
   true),
  ('cash', null, 'LINK-LAND',
   'Lacagta caddaanka ah waxaa lagu bixin karaa xafiiska LINK-LAND. La xiriir wakiilka si aad u hesho cinwaanka.',
   'Cash payments can be made at the LINK-LAND office. Contact the agent for the address.',
   false),
  ('bank', null, 'LINK-LAND',
   'Lacagta bangiga waxaa lagu dirayaa akoonka LINK-LAND. La xiriir maamulka si aad u hesho faahfaahin.',
   'Bank transfers are sent to the LINK-LAND account. Contact the team for details.',
   false)
on conflict (method) do nothing;

-- Agents ---------------------------------------------------------------------
insert into public.agents (id, email, full_name, phone, whatsapp, photo, bio, city, agency_name, verified, active) values
  (
    'a1000000-0000-4000-8000-000000000001',
    'ayaan@link-land.so',
    'Ayaan Cali',
    '+252615550001',
    '+252615550001',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=70',
    'Wakiil ku takhasusay guryaha iyo dhulka Muqdisho. Khibrad 8 sano ah oo ku saabsan iibka iyo kireynta.',
    'Mogadishu',
    'Ayaan Real Estate',
    true,
    true
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'mohamed@link-land.so',
    'Maxamed Xasan',
    '+252635550002',
    '+252635550002',
    'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=400&q=70',
    'Wakiil ka shaqeeya Hargeisa iyo hareeraheeda. Wuxuu ku takhasusay guryaha qoyska iyo dhulka la dejin karo.',
    'Hargeisa',
    'Horn Properties',
    true,
    true
  ),
  (
    'a1000000-0000-4000-8000-000000000003',
    'fartun@link-land.so',
    'Fartun Cabdi',
    '+252685550003',
    '+252685550003',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=400&q=70',
    'Wakiil Baidoa iyo Koonfurta dhexe. Waxay caawisaa macaamiisha dhul-beereedka iyo guryaha.',
    'Baidoa',
    'Bay Land Agency',
    false,
    true
  )
on conflict (id) do nothing;

-- Listings -------------------------------------------------------------------
insert into public.listings (
  id, title_so, title_en, description_so, description_en, type, purpose, price, currency,
  rent_period, size_m2, bedrooms, bathrooms, city, district, address, latitude, longitude,
  status, featured, featured_until, verified, agent_id, whatsapp, phone, views, created_at
) values
  (
    'b1000000-0000-4000-8000-000000000001',
    'Dhul 500m² ah oo ku yaal Hodan',
    '500m² land plot in Hodan',
    'Dhul 500 mitir laba jibbaaran ah oo ku yaal xaafadda Hodan, Muqdisho. Dhulka wuxuu leeyahay waddo weyn, biyo iyo koronto. Wuxuu ku habboon yahay dhismo guri ama ganacsi. Dukumeentiyada waa diyaar.',
    'A 500 sqm plot in Hodan, Mogadishu. Main road access, water and electricity nearby. Ideal for a family home or commercial building. Documents ready.',
    'land', 'sale', 45000, 'USD', null, 500, null, null,
    'Mogadishu', 'Hodan', 'Hodan, Muqdisho', 2.0469, 45.3182,
    'available', true, now() + interval '25 days', true,
    'a1000000-0000-4000-8000-000000000001', '+252615550001', '+252615550001', 148, now() - interval '2 days'
  ),
  (
    'b1000000-0000-4000-8000-000000000002',
    'Guri 4 qol ah oo kirada ah - Wadajir',
    '4-bedroom house for rent - Wadajir',
    'Guri casri ah oo 4 qol ah, 3 musqul, jiko weyn iyo barxad. Wuxuu ku yaal xaafad ammaan ah oo Wadajir, Muqdisho. Wuxuu leeyahay biyo, koronto iyo waardiyayaal 24 saac.',
    'Modern 4-bedroom house with 3 bathrooms, large kitchen and courtyard in a safe Wadajir neighbourhood. Water, electricity and 24h security.',
    'house', 'rent', 450, 'USD', 'monthly', 220, 4, 3,
    'Mogadishu', 'Wadajir', 'Wadajir, Muqdisho', 2.0333, 45.2833,
    'available', true, now() + interval '18 days', true,
    'a1000000-0000-4000-8000-000000000001', '+252615550001', '+252615550001', 231, now() - interval '1 day'
  ),
  (
    'b1000000-0000-4000-8000-000000000003',
    'Dhul 1000m² ah oo ku yaal Ahmed Dhagax',
    '1000m² land in Ahmed Dhagax',
    'Dhul ballaaran oo 1000m² ah oo ku yaal xaafadda Ahmed Dhagax, Hargeisa. Wuxuu ku habboon yahay dhismo guryo ama mashruuc ganacsi. Meel furan oo qorrax leh.',
    'Large 1000 sqm plot in Ahmed Dhagax, Hargeisa. Suitable for residential or commercial development. Open, sunny and easily accessible.',
    'land', 'sale', 70000, 'USD', null, 1000, null, null,
    'Hargeisa', 'Ahmed Dhagax', 'Ahmed Dhagax, Hargeisa', 9.5600, 44.0650,
    'available', false, null, true,
    'a1000000-0000-4000-8000-000000000002', '+252635550002', '+252635550002', 96, now() - interval '5 days'
  ),
  (
    'b1000000-0000-4000-8000-000000000004',
    'Guri 3 qol ah oo kirada ah - Jigjiga Yar',
    '3-bedroom house for rent - Jigjiga Yar',
    'Guri qurux badan oo 3 qol ah oo ku yaal Jigjiga Yar, Hargeisa. Wuxuu leeyahay 2 musqul, jiko iyo barxad yar. Deegaan deggan oo u dhow dugsiyada iyo suuqyada.',
    'Beautiful 3-bedroom home in Jigjiga Yar, Hargeisa. Two bathrooms, kitchen and small courtyard. Quiet area close to schools and markets.',
    'house', 'rent', 300, 'USD', 'monthly', 160, 3, 2,
    'Hargeisa', 'Jigjiga Yar', 'Jigjiga Yar, Hargeisa', 9.5450, 44.0450,
    'reserved', false, null, true,
    'a1000000-0000-4000-8000-000000000002', '+252635550002', '+252635550002', 177, now() - interval '8 days'
  ),
  (
    'b1000000-0000-4000-8000-000000000005',
    'Dhul 300m² ah oo ku yaal Isha Bay',
    '300m² land in Isha Bay',
    'Dhul 300m² ah oo ku yaal xaafadda Isha Bay, Baidoa. Wuxuu ku habboon yahay guri qoys. Dhulka waa nadiif oo diyaar u ah dhismo.',
    'A 300 sqm plot in Isha Bay, Baidoa. Ready for a family home, cleared and buildable.',
    'land', 'sale', 12000, 'USD', null, 300, null, null,
    'Baidoa', 'Isha Bay', 'Isha Bay, Baidoa', 3.1167, 43.6500,
    'available', false, null, false,
    'a1000000-0000-4000-8000-000000000003', '+252685550003', '+252685550003', 54, now() - interval '3 days'
  ),
  (
    'b1000000-0000-4000-8000-000000000006',
    'Guri 5 qol ah oo iib ah - Berdaale',
    '5-bedroom house for sale - Berdaale',
    'Guri weyn oo 5 qol ah oo ku yaal Berdaale, Baidoa. Wuxuu leeyahay 3 musqul, jiko, fasal weyn iyo barxad ballaaran. Wuxuu ku habboon yahay qoys weyn.',
    'Spacious 5-bedroom house in Berdaale, Baidoa with 3 bathrooms, kitchen, living room and large courtyard. Perfect for a large family.',
    'house', 'sale', 55000, 'USD', null, 320, 5, 3,
    'Baidoa', 'Berdaale', 'Berdaale, Baidoa', 3.1000, 43.6300,
    'available', false, null, false,
    'a1000000-0000-4000-8000-000000000003', '+252685550003', '+252685550003', 88, now() - interval '6 days'
  ),
  (
    'b1000000-0000-4000-8000-000000000007',
    'Dhul 800m² ah oo ku yaal Waddada Afgooye',
    '800m² land on Afgooye Road',
    'Dhul 800m² ah oo ku yaal waddada Afgooye, Muqdisho. Wuxuu leeyahay waddo laamiga ah iyo meel ganacsi oo fiican. Waa fursad maal-gashi.',
    'An 800 sqm plot on Afgooye Road, Mogadishu. Tarmac road frontage and excellent commercial potential. A solid investment opportunity.',
    'land', 'sale', 30000, 'USD', null, 800, null, null,
    'Mogadishu', 'Afgooye Road', 'Waddada Afgooye, Muqdisho', 2.0167, 45.2500,
    'sold', false, null, true,
    'a1000000-0000-4000-8000-000000000001', '+252615550001', '+252615550001', 312, now() - interval '20 days'
  ),
  (
    'b1000000-0000-4000-8000-000000000008',
    'Guri 2 qol ah oo kirada ah - Kaaraan',
    '2-bedroom house for rent - Kaaraan',
    'Guri yar oo 2 qol ah oo ku yaal Kaaraan, Muqdisho. Wuxuu leeyahay musqul iyo jiko. Wuxuu ku habboon yahay qoys yar ama shaqaale.',
    'Compact 2-bedroom home in Kaaraan, Mogadishu with bathroom and kitchen. Suitable for a small family or professionals.',
    'house', 'rent', 200, 'USD', 'monthly', 95, 2, 1,
    'Mogadishu', 'Kaaraan', 'Kaaraan, Muqdisho', 2.0500, 45.3500,
    'rented', false, null, false,
    'a1000000-0000-4000-8000-000000000001', '+252615550001', '+252615550001', 143, now() - interval '14 days'
  ),
  (
    'b1000000-0000-4000-8000-000000000009',
    'Dhul 250m² ah oo ku yaal Liido',
    '250m² land in Liido',
    'Dhul 250m² ah oo aad ugu dhow xeebta Liido, Muqdisho. Meel qurux badan oo ku habboon guri dalxiis ama shirkad. Dhulka waa la dejiyay.',
    'A 250 sqm plot close to Liido beach, Mogadishu. Beautiful location for a holiday home or boutique business. Serviced plot.',
    'land', 'sale', 60000, 'USD', null, 250, null, null,
    'Mogadishu', 'Liido', 'Liido, Muqdisho', 2.0333, 45.3667,
    'available', true, now() + interval '12 days', true,
    'a1000000-0000-4000-8000-000000000001', '+252615550001', '+252615550001', 402, now() - interval '10 hours'
  ),
  (
    'b1000000-0000-4000-8000-000000000010',
    'Guri 3 qol ah oo iib ah - Huriwaa',
    '3-bedroom house for sale - Huriwaa',
    'Guri 3 qol ah oo ku yaal Huriwaa, Muqdisho. Wuxuu u baahan yahay dayactir yar. Qiimaha waa mid macquul ah. Dukumeentiyada waa la hubinayaa.',
    'A 3-bedroom house in Huriwaa, Mogadishu. Needs minor renovation. Priced to sell. Documents under verification.',
    'house', 'sale', 38000, 'USD', null, 140, 3, 2,
    'Mogadishu', 'Huriwaa', 'Huriwaa, Muqdisho', 2.0667, 45.3333,
    'pending', false, null, false,
    'a1000000-0000-4000-8000-000000000001', '+252615550001', '+252615550001', 12, now() - interval '4 hours'
  ),
  (
    'b1000000-0000-4000-8000-000000000011',
    'Guri 3 qol ah oo kirada ah - Gacan Libaax',
    '3-bedroom house for rent - Gacan Libaax',
    'Guri 3 qol ah oo ku yaal Gacan Libaax, Hargeisa. Wuxuu leeyahay 2 musqul, jiko iyo barxad. Wuxuu ku yaal meel u dhow waddada weyn.',
    'A 3-bedroom house in Gacan Libaax, Hargeisa with 2 bathrooms, kitchen and courtyard. Close to the main road.',
    'house', 'rent', 250, 'USD', 'monthly', 150, 3, 2,
    'Hargeisa', 'Gacan Libaax', 'Gacan Libaax, Hargeisa', 9.5700, 44.0800,
    'pending', false, null, false,
    'a1000000-0000-4000-8000-000000000002', '+252635550002', '+252635550002', 7, now() - interval '2 hours'
  ),
  (
    'b1000000-0000-4000-8000-000000000012',
    'Dhul 400m² ah oo ku yaal Howlwadaag',
    '400m² land in Howlwadaag',
    'Dhul 400m² ah oo ku yaal Howlwadaag, Baidoa. Dukumeentiyada lama caddeyn. Wakiilka ayaa soo bandhigaya qiimo jaban.',
    'A 400 sqm plot in Howlwadaag, Baidoa. Documents not yet verified. Offered at a low price by the agent.',
    'land', 'sale', 9000, 'USD', null, 400, null, null,
    'Baidoa', 'Howlwadaag', 'Howlwadaag, Baidoa', 3.1200, 43.6400,
    'rejected', false, null, false,
    'a1000000-0000-4000-8000-000000000003', '+252685550003', '+252685550003', 3, now() - interval '1 day'
  )
on conflict (id) do nothing;

update public.listings
set rejection_reason = 'Dukumeentiyada dhulka lama xaqiijin. Fadlan soo geli warqadaha rasmiga ah.'
where id = 'b1000000-0000-4000-8000-000000000012'
  and rejection_reason is null;

-- Listing images -------------------------------------------------------------
insert into public.listing_images (id, listing_id, url, alt, sort_order, is_cover) values
  ('c1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000001', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1400&q=75', 'Dhul Hodan', 0, true),
  ('c1000000-0000-4000-8000-000000000102', 'b1000000-0000-4000-8000-000000000001', 'https://images.unsplash.com/photo-1500076656116-558758c991c1?auto=format&fit=crop&w=1400&q=75', 'Dhul Hodan 2', 1, false),

  ('c1000000-0000-4000-8000-000000000201', 'b1000000-0000-4000-8000-000000000002', 'https://images.unsplash.com/photo-1568605114967-8130f3a36994?auto=format&fit=crop&w=1400&q=75', 'Guri Wadajir', 0, true),
  ('c1000000-0000-4000-8000-000000000202', 'b1000000-0000-4000-8000-000000000002', 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1400&q=75', 'Guri Wadajir gudaha', 1, false),

  ('c1000000-0000-4000-8000-000000000301', 'b1000000-0000-4000-8000-000000000003', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1400&q=75', 'Dhul Hargeisa', 0, true),

  ('c1000000-0000-4000-8000-000000000401', 'b1000000-0000-4000-8000-000000000004', 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1400&q=75', 'Guri Hargeisa', 0, true),
  ('c1000000-0000-4000-8000-000000000402', 'b1000000-0000-4000-8000-000000000004', 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1400&q=75', 'Guri Hargeisa gudaha', 1, false),

  ('c1000000-0000-4000-8000-000000000501', 'b1000000-0000-4000-8000-000000000005', 'https://images.unsplash.com/photo-1500076656116-558758c991c1?auto=format&fit=crop&w=1400&q=75', 'Dhul Baidoa', 0, true),

  ('c1000000-0000-4000-8000-000000000601', 'b1000000-0000-4000-8000-000000000006', 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1400&q=75', 'Guri Baidoa', 0, true),
  ('c1000000-0000-4000-8000-000000000602', 'b1000000-0000-4000-8000-000000000006', 'https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?auto=format&fit=crop&w=1400&q=75', 'Guri Baidoa gudaha', 1, false),

  ('c1000000-0000-4000-8000-000000000701', 'b1000000-0000-4000-8000-000000000007', 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1400&q=75', 'Dhul Afgooye', 0, true),

  ('c1000000-0000-4000-8000-000000000801', 'b1000000-0000-4000-8000-000000000008', 'https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1400&q=75', 'Guri Kaaraan', 0, true),

  ('c1000000-0000-4000-8000-000000000901', 'b1000000-0000-4000-8000-000000000009', 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1400&q=75', 'Dhul Liido', 0, true),
  ('c1000000-0000-4000-8000-000000000902', 'b1000000-0000-4000-8000-000000000009', 'https://images.unsplash.com/photo-1523217582562-09d0def993a6?auto=format&fit=crop&w=1400&q=75', 'Dhul Liido 2', 1, false),

  ('c1000000-0000-4000-8000-000000000a01', 'b1000000-0000-4000-8000-000000000010', 'https://images.unsplash.com/photo-1449844908441-8829872d2607?auto=format&fit=crop&w=1400&q=75', 'Guri Huriwaa', 0, true),

  ('c1000000-0000-4000-8000-000000000b01', 'b1000000-0000-4000-8000-000000000011', 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=1400&q=75', 'Guri Gacan Libaax', 0, true),

  ('c1000000-0000-4000-8000-000000000c01', 'b1000000-0000-4000-8000-000000000012', 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1400&q=75', 'Dhul Howlwadaag', 0, true)
on conflict (id) do nothing;

-- Inquiries ------------------------------------------------------------------
insert into public.inquiries (id, listing_id, agent_id, name, phone, message, status, is_read, created_at) values
  (
    'e1000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'Cabdiraxmaan Yuusuf', '+252612223334',
    'Salaam, ma dhulka Hodan wali waa diyaar? Waxaan jeclaan lahaa inaan booqdo berri.',
    'new', false, now() - interval '3 hours'
  ),
  (
    'e1000000-0000-4000-8000-000000000002',
    'b1000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'Hodan Maxamuud', '+252617778899',
    'Qiimaha guriga ma lagu daray biyaha iyo korontada?',
    'contacted', true, now() - interval '2 days'
  ),
  (
    'e1000000-0000-4000-8000-000000000003',
    'b1000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000002',
    'Ahmed Farah', '+252634445566',
    'Waxaan xiiseynayaa guriga Jigjiga Yar. Ma jiraa meel bannaan oo baabuurta la dhigto?',
    'closed', true, now() - interval '6 days'
  )
on conflict (id) do nothing;

-- Payments (demo) ------------------------------------------------------------
insert into public.payments (
  id, listing_id, agent_id, customer_name, customer_phone, amount, currency,
  method, purpose, reference, status, notes, confirmed_at, created_at
) values
  (
    'd1000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000002',
    'Ahmed Farah', '+252634445566', 100, 'USD',
    'evc_plus', 'deposit', 'EVC-8842190', 'confirmed',
    'Ballan la xaqiijiyay. Macmiilka waa la soo wacay.', now() - interval '5 days', now() - interval '5 days'
  ),
  (
    'd1000000-0000-4000-8000-000000000002',
    'b1000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'Cabdiraxmaan Yuusuf', '+252612223334', 100, 'USD',
    'zaad', 'deposit', 'ZAAD-552013', 'pending',
    'Waxaan sugayaa caddaynta lacagta.', null, now() - interval '2 hours'
  ),
  (
    'd1000000-0000-4000-8000-000000000003',
    'b1000000-0000-4000-8000-000000000009',
    'a1000000-0000-4000-8000-000000000001',
    'LINK-LAND Agent', '+252615550001', 25, 'USD',
    'edahab', 'featured_boost', 'EDH-119902', 'confirmed',
    'Boost la xaqiijiyay 30 maalmood.', now() - interval '10 days', now() - interval '10 days'
  ),
  (
    'd1000000-0000-4000-8000-000000000004',
    'b1000000-0000-4000-8000-000000000011',
    'a1000000-0000-4000-8000-000000000002',
    'Maxamed Xasan', '+252635550002', 10, 'USD',
    'evc_plus', 'listing_fee', 'EVC-773311', 'pending',
    'Kharashka gelinta liiska.', null, now() - interval '1 hour'
  )
on conflict (id) do nothing;

select set_config('app.bypass_guards', 'off', false);

commit;
