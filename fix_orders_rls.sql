-- =============================================================================
-- SOLUCIÓN AL ERROR DE RLS (ROW-LEVEL SECURITY) EN LA TABLA ORDERS
-- Copia y pega todo este código en el SQL Editor de tu Dashboard en Supabase y dale RUN
-- =============================================================================

-- 1. Permitir que user_id sea opcional (para clientes sin login de correo/contraseña)
ALTER TABLE public.orders ALTER COLUMN user_id DROP NOT NULL;

-- 2. Asegurar que existan todas las columnas de cliente y envío
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS customer_phone TEXT,
ADD COLUMN IF NOT EXISTS customer_email TEXT,
ADD COLUMN IF NOT EXISTS is_delivery BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS branch_name TEXT,
ADD COLUMN IF NOT EXISTS delivery_address TEXT,
ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_distance_km NUMERIC,
ADD COLUMN IF NOT EXISTS shipping_cost NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'Tarjeta (Simulación)';

-- 3. Eliminar políticas antiguas que bloquean la creación de órdenes
DROP POLICY IF EXISTS "Usuarios pueden insertar sus propias órdenes" ON public.orders;
DROP POLICY IF EXISTS "Permitir crear ordenes a todos" ON public.orders;
DROP POLICY IF EXISTS "Permitir crear ordenes a cualquier usuario" ON public.orders;

-- 4. Permitir INSERT público en orders (para que cualquier cliente pueda crear su orden)
CREATE POLICY "Permitir crear ordenes a todos" 
ON public.orders 
FOR INSERT 
TO public, anon, authenticated 
WITH CHECK (true);

-- 5. Permitir SELECT en orders (necesario para el .select().single() al crear la orden y verlas en dashboard)
DROP POLICY IF EXISTS "Permitir leer ordenes" ON public.orders;
DROP POLICY IF EXISTS "Usuarios pueden ver sus propias órdenes" ON public.orders;
CREATE POLICY "Permitir leer ordenes" 
ON public.orders 
FOR SELECT 
TO public, anon, authenticated 
USING (true);

-- 6. Permitir UPDATE en orders (para que el admin pueda cambiar de pendiente a completado)
DROP POLICY IF EXISTS "Permitir actualizar ordenes" ON public.orders;
DROP POLICY IF EXISTS "Usuarios pueden actualizar sus propias órdenes" ON public.orders;
CREATE POLICY "Permitir actualizar ordenes" 
ON public.orders 
FOR UPDATE 
TO public, anon, authenticated 
USING (true);

-- 7. Ajustar políticas RLS para order_items
DROP POLICY IF EXISTS "Usuarios pueden insertar items a sus órdenes" ON public.order_items;
DROP POLICY IF EXISTS "Permitir crear items a todos" ON public.order_items;
CREATE POLICY "Permitir crear items a todos" 
ON public.order_items 
FOR INSERT 
TO public, anon, authenticated 
WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios pueden ver items de sus órdenes" ON public.order_items;
DROP POLICY IF EXISTS "Permitir leer order_items" ON public.order_items;
CREATE POLICY "Permitir leer order_items" 
ON public.order_items 
FOR SELECT 
TO public, anon, authenticated 
USING (true);
